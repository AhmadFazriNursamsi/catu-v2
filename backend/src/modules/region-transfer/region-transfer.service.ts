import { BadRequestException, ConflictException, ForbiddenException, Injectable, Logger } from '@nestjs/common';
import { InjectDataSource } from '@nestjs/typeorm';
import { DataSource } from 'typeorm';
import { AccountStatusService } from '../../common/access/account-status.service';
import { FcmService } from '../../fcm.service';
import { RegionIds, isMove, takeRegionFields, usesTransferFlow } from './region-transfer-rules';

/** Kolom id bertipe bigint dikembalikan driver sebagai teks; samakan menjadi angka sebelum dibandingkan. */
const num = (v: unknown): number | null => (v == null ? null : Number(v));

/**
 * Perpindahan wilayah gereja Umat: wilayah baru langsung berlaku, akun berstatus PENDING_APPROVAL sampai pengurus
 * lingkungan tujuan menyetujui. Bila ditolak, wilayah lama dikembalikan dan akun kembali APPROVED.
 */
@Injectable()
export class RegionTransferService {
  private readonly logger = new Logger(RegionTransferService.name);

  constructor(
    @InjectDataSource() private readonly dataSource: DataSource,
    private readonly accounts: AccountStatusService,
    private readonly fcm: FcmService,
  ) {}

  /** Dipanggil sebelum menyimpan profil: mencabut isian wilayah dari DTO; mengembalikan tujuan bila memang berpindah. */
  async extract(userId: number, dto: Record<string, any>): Promise<RegionIds | null> {
    const wanted = takeRegionFields(dto);
    if (!wanted) return null;
    const rows = await this.dataSource.query(
      `SELECT r.code AS role_code, u.account_status, p.keuskupan_id, p.paroki_id, p.wilayah_id, p.lingkungan_id
       FROM auth_users u JOIN roles r ON r.id = u.role_id LEFT JOIN user_profiles p ON p.user_id = u.id WHERE u.id = $1`,
      [userId],
    );
    if (rows.length === 0) return null;
    const cur = rows[0];
    const current: RegionIds = { keuskupanId: num(cur.keuskupan_id), parokiId: num(cur.paroki_id), wilayahId: num(cur.wilayah_id), lingkunganId: num(cur.lingkungan_id) };
    if (!isMove(current, wanted)) return null;
    if (!usesTransferFlow(cur.role_code)) throw new ForbiddenException('Perubahan wilayah gereja untuk peran ini dilakukan oleh Admin.');
    if (cur.account_status !== 'APPROVED') throw new ConflictException('Akun Anda sedang menunggu persetujuan; wilayah belum dapat diubah.');
    if (!wanted.lingkunganId) throw new BadRequestException('Pilih lingkungan tujuan terlebih dahulu.');
    const chain = await this.dataSource.query(
      `SELECT l.id AS lingkungan_id, w.id AS wilayah_id, par.id AS paroki_id, par.keuskupan_id
       FROM lingkungan l JOIN wilayah w ON w.id = l.wilayah_id JOIN paroki par ON par.id = w.paroki_id WHERE l.id = $1`,
      [wanted.lingkunganId],
    );
    if (chain.length === 0) throw new BadRequestException('Lingkungan tujuan tidak ditemukan.');
    return { keuskupanId: num(chain[0].keuskupan_id), parokiId: num(chain[0].paroki_id), wilayahId: num(chain[0].wilayah_id), lingkunganId: num(chain[0].lingkungan_id) };
  }

  /** Menerapkan wilayah baru dan menunggu persetujuan. Dipanggil setelah profil lain tersimpan. */
  async request(userId: number, to: RegionIds): Promise<void> {
    await this.dataSource.transaction(async (m) => {
      const cur = (await m.query('SELECT keuskupan_id, paroki_id, wilayah_id, lingkungan_id FROM user_profiles WHERE user_id = $1', [userId]))[0];
      await m.query(
        `INSERT INTO region_transfer_requests (user_id, from_keuskupan_id, from_paroki_id, from_wilayah_id, from_lingkungan_id,
           to_keuskupan_id, to_paroki_id, to_wilayah_id, to_lingkungan_id)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)`,
        [userId, cur.keuskupan_id, cur.paroki_id, cur.wilayah_id, cur.lingkungan_id, to.keuskupanId, to.parokiId, to.wilayahId, to.lingkunganId],
      );
      await m.query('UPDATE user_profiles SET keuskupan_id = $1, paroki_id = $2, wilayah_id = $3, lingkungan_id = $4 WHERE user_id = $5', [to.keuskupanId, to.parokiId, to.wilayahId, to.lingkunganId, userId]);
      await m.query(`UPDATE auth_users SET account_status = 'PENDING_APPROVAL', approval_assigned_to_user_id = NULL, updated_at = CURRENT_TIMESTAMP WHERE id = $1`, [userId]);
    });
    this.accounts.invalidate(userId);
    await this.notifyApprovers(userId, to.lingkunganId!);
  }

  /** Memproses persetujuan/penolakan bila [targetId] punya permintaan pindah terbuka; null bila tidak ada. */
  async resolve(targetId: number, approverId: number, action: 'APPROVE' | 'REJECT', reason?: string) {
    const open = await this.dataSource.query(`SELECT * FROM region_transfer_requests WHERE user_id = $1 AND status = 'PENDING'`, [targetId]);
    if (open.length === 0) return null;
    const req = open[0];
    const approved = action === 'APPROVE';
    await this.dataSource.transaction(async (m) => {
      if (!approved) {
        await m.query('UPDATE user_profiles SET keuskupan_id = $1, paroki_id = $2, wilayah_id = $3, lingkungan_id = $4 WHERE user_id = $5', [req.from_keuskupan_id, req.from_paroki_id, req.from_wilayah_id, req.from_lingkungan_id, targetId]);
      }
      await m.query(`UPDATE auth_users SET account_status = 'APPROVED', updated_at = CURRENT_TIMESTAMP WHERE id = $1`, [targetId]);
      await m.query(`UPDATE region_transfer_requests SET status = $1, decided_by = $2, rejection_reason = $3, decided_at = now() WHERE id = $4`, [approved ? 'APPROVED' : 'REJECTED', approverId, approved ? null : reason || null, req.id]);
      await m.query('INSERT INTO user_approvals (target_user_id, approver_user_id, action, rejection_reason) VALUES ($1, $2, $3, $4)', [targetId, approverId, action, approved ? null : reason || null]);
    });
    this.accounts.invalidate(targetId);
    const names = await this.dataSource.query(`SELECT name FROM lingkungan WHERE id = $1`, [req.to_lingkungan_id]);
    const tujuan = names[0]?.name ?? 'lingkungan tujuan';
    await this.notify(
      targetId,
      approved ? 'Perpindahan lingkungan disetujui' : 'Perpindahan lingkungan ditolak',
      approved ? `Anda kini terdaftar di ${tujuan}.` : `Permintaan pindah ke ${tujuan} ditolak. Anda tetap di lingkungan semula.${reason ? ` Alasan: ${reason}` : ''}`,
      approved ? 'REGION_TRANSFER_APPROVED' : 'REGION_TRANSFER_REJECTED',
    );
    return { statusCode: 200, message: approved ? 'Perpindahan lingkungan disetujui.' : 'Perpindahan lingkungan ditolak; wilayah lama dikembalikan.', accountStatus: 'APPROVED' };
  }

  /** Menambahkan keterangan asal pada baris daftar persetujuan yang berasal dari permintaan pindah. */
  async annotate<T extends { id: number | string }>(rows: T[]): Promise<Array<T & { transfer_from?: string }>> {
    if (rows.length === 0) return rows;
    const found = await this.dataSource.query(
      `SELECT t.user_id, CONCAT_WS(' · ', l.name, par.name) AS asal
       FROM region_transfer_requests t LEFT JOIN lingkungan l ON l.id = t.from_lingkungan_id LEFT JOIN paroki par ON par.id = t.from_paroki_id
       WHERE t.status = 'PENDING' AND t.user_id = ANY($1::int[])`,
      [rows.map((r) => Number(r.id))],
    );
    const byUser = new Map<number, string>(found.map((f: any) => [Number(f.user_id), f.asal || 'wilayah sebelumnya']));
    return rows.map((r) => (byUser.has(Number(r.id)) ? { ...r, transfer_from: byUser.get(Number(r.id)) } : r));
  }

  private async notifyApprovers(userId: number, lingkunganId: number): Promise<void> {
    try {
      const who = await this.dataSource.query(
        `SELECT u.id FROM auth_users u JOIN user_profiles p ON p.user_id = u.id JOIN roles r ON r.id = u.role_id
         WHERE p.lingkungan_id = $1 AND r.code = 'PENGURUS_LINGKUNGAN' AND u.account_status = 'APPROVED' AND p.is_jabatan_active IS NOT FALSE AND u.id <> $2`,
        [lingkunganId, userId],
      );
      const name = (await this.dataSource.query('SELECT full_name FROM user_profiles WHERE user_id = $1', [userId]))[0]?.full_name ?? 'Seorang umat';
      for (const w of who) await this.notify(w.id, 'Permintaan pindah lingkungan', `${name} meminta pindah ke lingkungan Anda dan menunggu persetujuan.`, 'REGION_TRANSFER_REQUEST');
    } catch (e: any) {
      this.logger.error(`Gagal memberi tahu pengurus: ${e.message}`);
    }
  }

  private async notify(userId: number, title: string, body: string, type: string): Promise<void> {
    try {
      await this.dataSource.query(`INSERT INTO notifications (user_id, title, body, type, is_read, created_at) VALUES ($1, $2, $3, $4, false, CURRENT_TIMESTAMP)`, [userId, title, body, type]);
      await this.fcm.sendPushToUsers(userId, { title, body, data: { type, targetUserId: String(userId) } });
    } catch (e: any) {
      this.logger.error(`Gagal mengirim notifikasi ${type}: ${e.message}`);
    }
  }
}
