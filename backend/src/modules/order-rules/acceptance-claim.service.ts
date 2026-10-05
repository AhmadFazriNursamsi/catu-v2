import { ConflictException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { InjectDataSource } from '@nestjs/typeorm';
import { DataSource } from 'typeorm';
import { ONGOING_STATUSES } from './order-status-machine';

export interface ClaimInput {
  orderId: number;
  itemId?: number | null;
  romoId: number;
  /** Romo Paroki hanya untuk parokinya, Romo Ordo hanya untuk kotanya. Admin dan Koordinator dikecualikan. */
  enforceTerritory: boolean;
}

export interface Claim {
  /** false bila Romo yang sama sudah menerima sebelumnya (tidak ada yang perlu diproses ulang). */
  claimed: boolean;
  /** Membatalkan klaim bila proses lanjutan gagal. */
  release: () => Promise<void>;
}

/**
 * Penerimaan pelayanan yang atomik: satu UPDATE bersyarat menetapkan Romo hanya bila pelayanan masih PENDING dan
 * belum ada Romo. Dua Romo yang menerima bersamaan tidak lagi sama-sama berhasil: yang kalah mendapat 409.
 */
@Injectable()
export class AcceptanceClaimService {
  constructor(@InjectDataSource() private readonly dataSource: DataSource) {}

  async claim(input: ClaimInput): Promise<Claim> {
    if (input.enforceTerritory) await this.assertTerritory(input.orderId, input.romoId);

    const item = !!input.itemId;
    const table = item ? 'order_items' : 'orders';
    const where = item ? 'id = $2 AND order_id = $3' : 'id = $2';
    const params = item ? [input.romoId, input.itemId, input.orderId] : [input.romoId, input.orderId];
    const result = await this.dataSource.query(
      `UPDATE ${table} SET accepted_romo_id = $1 WHERE ${where} AND accepted_romo_id IS NULL AND status::text = 'PENDING' RETURNING id`,
      params,
    );
    // TypeORM (pg) mengembalikan [baris, jumlah] untuk UPDATE ... RETURNING
    const rows = Array.isArray(result[0]) ? result[0] : result;
    if (rows.length > 0) {
      return {
        claimed: true,
        release: async () => {
          await this.dataSource.query(
            `UPDATE ${table} SET accepted_romo_id = NULL WHERE ${where} AND accepted_romo_id = $1 AND status::text = 'PENDING'`,
            params,
          );
        },
      };
    }
    return this.explainRejection(input, table, item);
  }

  private async explainRejection(input: ClaimInput, table: string, item: boolean): Promise<Claim> {
    const rows = await this.dataSource.query(
      item ? 'SELECT status::text AS status, accepted_romo_id FROM order_items WHERE id = $1 AND order_id = $2' : 'SELECT status::text AS status, accepted_romo_id FROM orders WHERE id = $1',
      item ? [input.itemId, input.orderId] : [input.orderId],
    );
    if (rows.length === 0) throw new NotFoundException(item ? 'Misa pelayanan tidak ditemukan.' : 'Order tidak ditemukan.');
    const { status, accepted_romo_id: accepted } = rows[0];
    if (accepted && Number(accepted) === Number(input.romoId) && (ONGOING_STATUSES as string[]).includes(status)) return { claimed: false, release: async () => undefined };
    if (accepted) throw new ConflictException('Pelayanan ini sudah diterima oleh Romo lain.');
    throw new ConflictException(`Pelayanan ini sudah berstatus ${status} dan tidak dapat diterima.`);
  }

  /** Romo Paroki: paroki sama dengan paroki pelayanan. Romo Ordo: kota sama dengan kota pelayanan. */
  private async assertTerritory(orderId: number, romoId: number): Promise<void> {
    const rows = await this.dataSource.query(
      `SELECT r.code AS role_code, rp.paroki_id AS romo_paroki, rp.kabupaten_kota_id AS romo_kota,
              COALESCE(o.paroki_id, pem.paroki_id) AS order_paroki, COALESCE(o.kabupaten_kota_id, pem.kabupaten_kota_id) AS order_kota
       FROM orders o
       LEFT JOIN user_profiles pem ON pem.user_id = o.user_id
       JOIN auth_users u ON u.id = $2 JOIN roles r ON r.id = u.role_id
       LEFT JOIN user_profiles rp ON rp.user_id = u.id
       WHERE o.id = $1`,
      [orderId, romoId],
    );
    if (rows.length === 0) throw new NotFoundException('Order tidak ditemukan.');
    const x = rows[0];
    const same = (a: unknown, b: unknown) => a != null && b != null && String(a) === String(b);
    if (x.role_code === 'ROMO_PAROKI' && !same(x.romo_paroki, x.order_paroki)) {
      throw new ForbiddenException('Pelayanan ini berada di luar paroki Anda.');
    }
    if (x.role_code === 'ROMO_ORDO' && !same(x.romo_kota, x.order_kota)) {
      throw new ForbiddenException('Pelayanan ini berada di luar kota tugas Anda.');
    }
  }
}
