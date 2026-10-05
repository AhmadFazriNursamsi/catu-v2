import { BadRequestException, ConflictException, Injectable, Logger } from '@nestjs/common';
import { InjectDataSource } from '@nestjs/typeorm';
import * as bcrypt from 'bcrypt';
import { DataSource } from 'typeorm';
import { generatePassword, normalizePhone } from './romo-registration-rules';

export interface RegisterRomoInput {
  fullName: string;
  phoneNumber: string;
  roleCode: 'ROMO_PAROKI' | 'ROMO_ORDO';
  parokiId?: number;
  ordoId?: number;
}

/** Pelayanan (hasil evaluasi KoordinatorAssignmentService) yang menjadi alasan Koordinator mendaftarkan Romo. */
export interface OrderScope {
  paroki_id: number | null;
  kabupaten_kota_id: number | null;
  keuskupan_id: number | null;
}

/**
 * Koordinator mendaftarkan akun Romo yang belum terdaftar: langsung aktif (tanpa persetujuan admin atau Ketua Romo)
 * dengan kata sandi acak yang dikembalikan sekali agar Koordinator dapat menyampaikannya.
 */
@Injectable()
export class RomoRegistrationService {
  private readonly logger = new Logger(RomoRegistrationService.name);

  constructor(@InjectDataSource() private readonly dataSource: DataSource) {}

  /** Pilihan paroki (se-keuskupan pelayanan) dan ordo untuk formulir. */
  async options(order: OrderScope) {
    const paroki = await this.dataSource.query(
      'SELECT id, name FROM paroki WHERE ($1::int IS NULL OR keuskupan_id = $1::int) ORDER BY name',
      [order.keuskupan_id],
    );
    const ordo = await this.dataSource.query('SELECT id, name FROM ordo ORDER BY name');
    return {
      parokis: paroki.map((p: any) => ({ id: Number(p.id), name: p.name })),
      ordos: ordo.map((o: any) => ({ id: Number(o.id), name: o.name })),
      defaultParokiId: order.paroki_id ? Number(order.paroki_id) : null,
    };
  }

  async register(order: OrderScope, input: RegisterRomoInput) {
    const fullName = String(input.fullName ?? '').trim().replace(/\s+/g, ' ');
    if (fullName.length < 3) throw new BadRequestException('Nama lengkap Romo minimal 3 karakter.');
    const phone = normalizePhone(input.phoneNumber);
    if (!phone) throw new BadRequestException('Nomor HP tidak valid. Contoh: 0812 3456 7890.');
    if (!['ROMO_PAROKI', 'ROMO_ORDO'].includes(input.roleCode)) throw new BadRequestException('Jenis Romo tidak valid.');

    let parokiId: number | null = null;
    let ordoId: number | null = null;
    let affiliation = '';
    if (input.roleCode === 'ROMO_PAROKI') {
      const paroki = await this.dataSource.query('SELECT id, name, keuskupan_id FROM paroki WHERE id = $1', [input.parokiId ?? 0]);
      if (paroki.length === 0) throw new BadRequestException('Paroki wajib dipilih untuk Romo Paroki.');
      if (order.keuskupan_id && String(paroki[0].keuskupan_id) !== String(order.keuskupan_id)) {
        throw new BadRequestException('Paroki harus berada di keuskupan pelayanan ini.');
      }
      parokiId = Number(paroki[0].id);
      affiliation = paroki[0].name;
    } else {
      const ordo = await this.dataSource.query('SELECT id, name FROM ordo WHERE id = $1', [input.ordoId ?? 0]);
      if (ordo.length === 0) throw new BadRequestException('Ordo / tarekat wajib dipilih untuk Romo Ordo.');
      if (!order.kabupaten_kota_id) throw new BadRequestException('Pelayanan ini tidak memiliki kota, Romo Ordo tidak dapat didaftarkan.');
      ordoId = Number(ordo[0].id);
      affiliation = ordo[0].name;
    }

    const existing = await this.dataSource.query(
      'SELECT p.full_name FROM auth_users u LEFT JOIN user_profiles p ON p.user_id = u.id WHERE u.phone_number = $1',
      [phone],
    );
    if (existing.length > 0) {
      throw new ConflictException(`Nomor ${phone} sudah terdaftar${existing[0].full_name ? ` atas nama ${existing[0].full_name}` : ''}. Cari Romo tersebut di daftar.`);
    }

    const role = await this.dataSource.query('SELECT id FROM roles WHERE code = $1', [input.roleCode]);
    if (role.length === 0) throw new BadRequestException('Peran Romo tidak tersedia.');
    const password = generatePassword();
    const hash = await bcrypt.hash(password, 10);

    const runner = this.dataSource.createQueryRunner();
    await runner.connect();
    await runner.startTransaction();
    try {
      const user = await runner.query(
        `INSERT INTO auth_users (phone_number, password_hash, role_id, account_status, approval_assigned_to_user_id)
         VALUES ($1, $2, $3, 'APPROVED', NULL) RETURNING id`,
        [phone, hash, role[0].id],
      );
      await runner.query(
        `INSERT INTO user_profiles (user_id, full_name, keuskupan_id, paroki_id, kabupaten_kota_id, ordo_id, romo_position, is_jabatan_active)
         VALUES ($1, $2, $3, $4, $5, $6, 'ROMO_BIASA', TRUE)`,
        [user[0].id, fullName, order.keuskupan_id || null, parokiId, order.kabupaten_kota_id || null, ordoId],
      );
      await runner.commitTransaction();
      this.logger.log(`Romo ${user[0].id} (${input.roleCode}) didaftarkan Koordinator dan langsung aktif`);
      return {
        romo: {
          id: Number(user[0].id),
          fullName,
          roleCode: input.roleCode,
          affiliation,
          local: true,
        },
        phoneNumber: phone,
        temporaryPassword: password,
      };
    } catch (err) {
      await runner.rollbackTransaction();
      throw err;
    } finally {
      await runner.release();
    }
  }
}
