import { BadRequestException, ConflictException, Injectable, Logger, ServiceUnavailableException } from '@nestjs/common';
import { InjectDataSource } from '@nestjs/typeorm';
import * as bcrypt from 'bcrypt';
import { DataSource } from 'typeorm';
import { WhatsappService } from '../whatsapp/whatsapp.service';
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
  order_number?: string;
  category_name?: string;
  scheduled_date?: string | null;
  location_name?: string | null;
}

/**
 * Koordinator mendaftarkan akun Romo yang belum terdaftar: langsung aktif (tanpa persetujuan admin atau Ketua Romo)
 * dengan kata sandi acak yang dikirim langsung ke WhatsApp Romo (tidak pernah dikembalikan ke aplikasi Koordinator).
 */
@Injectable()
export class RomoRegistrationService {
  private readonly logger = new Logger(RomoRegistrationService.name);

  constructor(
    @InjectDataSource() private readonly dataSource: DataSource,
    private readonly wa: WhatsappService,
  ) {}

  /** Pilihan keuskupan, paroki (semua keuskupan; Romo bisa dari keuskupan mana pun), dan ordo untuk formulir. */
  async options(order: OrderScope) {
    const keuskupan = await this.dataSource.query('SELECT k.id, k.name FROM keuskupan k WHERE EXISTS (SELECT 1 FROM paroki p WHERE p.keuskupan_id = k.id) ORDER BY k.name');
    const paroki = await this.dataSource.query('SELECT id, name, keuskupan_id FROM paroki ORDER BY name');
    const ordo = await this.dataSource.query('SELECT id, name FROM ordo ORDER BY name');
    return {
      keuskupans: keuskupan.map((k: any) => ({ id: Number(k.id), name: k.name })),
      parokis: paroki.map((p: any) => ({ id: Number(p.id), name: p.name, keuskupanId: Number(p.keuskupan_id) })),
      ordos: ordo.map((o: any) => ({ id: Number(o.id), name: o.name })),
      defaultKeuskupanId: order.keuskupan_id ? Number(order.keuskupan_id) : null,
      defaultParokiId: order.paroki_id ? Number(order.paroki_id) : null,
    };
  }

  private welcomeText(fullName: string, phone: string, password: string, order: OrderScope): string {
    const service = [order.category_name, order.order_number ? `(${order.order_number})` : ''].filter(Boolean).join(' ');
    const raw: any = order.scheduled_date;
    const day = raw instanceof Date ? raw : raw ? new Date(`${String(raw).slice(0, 10)}T00:00:00`) : null;
    const when = day && !isNaN(day.getTime()) ? ` pada ${day.toLocaleDateString('id-ID', { day: 'numeric', month: 'long', year: 'numeric' })}` : '';
    const where = order.location_name ? ` di ${order.location_name}` : '';
    return (
      `*CATU* - Shalom ${fullName},\n\n` +
      `Anda didaftarkan oleh Koordinator untuk melayani ${service || 'sebuah pelayanan'}${when}${where}. Pelayanan ini sudah tercatat Anda terima.\n\n` +
      `Akun CATU Anda sudah aktif:\nNomor HP: ${phone}\nKata sandi sementara: *${password}*\n\n` +
      `Silakan masuk ke aplikasi CATU, lalu segera ganti kata sandi Anda. Jangan berikan kata sandi ini kepada siapa pun.`
    );
  }

  async register(order: OrderScope, input: RegisterRomoInput) {
    const fullName = String(input.fullName ?? '').trim().replace(/\s+/g, ' ');
    if (fullName.length < 3) throw new BadRequestException('Nama lengkap Romo minimal 3 karakter.');
    const phone = normalizePhone(input.phoneNumber);
    if (!phone) throw new BadRequestException('Nomor HP tidak valid. Contoh: 0812 3456 7890.');
    if (!['ROMO_PAROKI', 'ROMO_ORDO'].includes(input.roleCode)) throw new BadRequestException('Jenis Romo tidak valid.');

    let parokiId: number | null = null;
    let ordoId: number | null = null;
    let keuskupanId: number | null = order.keuskupan_id ? Number(order.keuskupan_id) : null;
    let affiliation = '';
    if (input.roleCode === 'ROMO_PAROKI') {
      const paroki = await this.dataSource.query('SELECT id, name, keuskupan_id FROM paroki WHERE id = $1', [input.parokiId ?? 0]);
      if (paroki.length === 0) throw new BadRequestException('Paroki wajib dipilih untuk Romo Paroki.');
      parokiId = Number(paroki[0].id);
      keuskupanId = paroki[0].keuskupan_id ? Number(paroki[0].keuskupan_id) : null;
      affiliation = paroki[0].name;
    } else {
      const ordo = await this.dataSource.query('SELECT id, name FROM ordo WHERE id = $1', [input.ordoId ?? 0]);
      if (ordo.length === 0) throw new BadRequestException('Ordo / tarekat wajib dipilih untuk Romo Ordo.');
      if (!order.kabupaten_kota_id) throw new BadRequestException('Pelayanan ini tidak memiliki kota, Romo Ordo tidak dapat didaftarkan.');
      ordoId = Number(ordo[0].id);
      affiliation = ordo[0].name;
    }

    // Kota pelayanan hanya diwariskan bila Romo berasal dari keuskupan pelayanan yang sama.
    const kotaId = !keuskupanId || String(keuskupanId) === String(order.keuskupan_id) ? order.kabupaten_kota_id || null : null;
    const existing = await this.dataSource.query(
      'SELECT p.full_name FROM auth_users u LEFT JOIN user_profiles p ON p.user_id = u.id WHERE u.phone_number = $1',
      [phone],
    );
    if (existing.length > 0) {
      throw new ConflictException(`Nomor ${phone} sudah terdaftar${existing[0].full_name ? ` atas nama ${existing[0].full_name}` : ''}. Cari Romo tersebut di daftar.`);
    }

    const role = await this.dataSource.query('SELECT id FROM roles WHERE code = $1', [input.roleCode]);
    if (role.length === 0) throw new BadRequestException('Peran Romo tidak tersedia.');
    if (!this.wa.enabled) throw new ServiceUnavailableException('Layanan WhatsApp belum aktif, Romo belum dapat didaftarkan. Hubungi admin CATU.');
    const password = generatePassword();
    const hash = await bcrypt.hash(password, 10);

    const runner = this.dataSource.createQueryRunner();
    await runner.connect();
    await runner.startTransaction();
    try {
      const user = await runner.query(
        `INSERT INTO auth_users (phone_number, password_hash, role_id, account_status, approval_assigned_to_user_id, must_change_password)
         VALUES ($1, $2, $3, 'APPROVED', NULL, TRUE) RETURNING id`,
        [phone, hash, role[0].id],
      );
      await runner.query(
        `INSERT INTO user_profiles (user_id, full_name, keuskupan_id, paroki_id, kabupaten_kota_id, ordo_id, romo_position, is_jabatan_active)
         VALUES ($1, $2, $3, $4, $5, $6, 'ROMO_BIASA', TRUE)`,
        [user[0].id, fullName, keuskupanId, parokiId, kotaId, ordoId],
      );
      // Kirim kredensial sebelum commit: bila WhatsApp gagal, akun dibatalkan agar tidak ada akun yang kata sandinya tidak diketahui siapa pun.
      const sent = await this.wa.send(phone, this.welcomeText(fullName, phone, password, order), { priority: 'normal' });
      if (!sent.ok) throw new ServiceUnavailableException(`Pesan WhatsApp ke Romo gagal dikirim (${sent.message}). Romo belum didaftarkan, coba lagi.`);
      await runner.commitTransaction();
      this.logger.log(`Romo ${user[0].id} (${input.roleCode}) didaftarkan Koordinator, kredensial dikirim lewat WhatsApp`);
      return {
        romo: {
          id: Number(user[0].id),
          fullName,
          roleCode: input.roleCode,
          affiliation,
          local: true,
        },
        phoneNumber: phone,
        notified: true,
      };
    } catch (err) {
      await runner.rollbackTransaction();
      throw err;
    } finally {
      await runner.release();
    }
  }
}
