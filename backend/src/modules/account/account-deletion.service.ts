import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectDataSource } from '@nestjs/typeorm';
import * as bcrypt from 'bcrypt';
import { DataSource, EntityManager } from 'typeorm';
import { AccountStatusService } from '../../common/access/account-status.service';
import { ADMIN_ROLES } from '../../common/access/role-groups';

export const DELETED_USER_NAME = 'Pengguna terhapus';

/** Status pelayanan yang masih berjalan: akun tidak boleh dihapus selama masih terikat salah satunya. */
const ACTIVE_ORDER_STATUSES = ['PENDING', 'CONFIRMED', 'IN_PROGRESS'];

/**
 * Nomor pengganti untuk akun terhapus: memenuhi CHECK nomor HP (9-16 digit), unik per akun, dan tidak mungkin dimiliki
 * pendaftar sungguhan (nomor terdaftar selalu berawalan 62). Nomor asli dibebaskan sehingga dapat didaftarkan ulang.
 */
export function deletedPhoneNumber(userId: number): string {
  return `000${String(userId).padStart(10, '0')}`;
}

/**
 * Penghapusan akun oleh pemiliknya (App Store 5.1.1(v)). Data pribadi dianonimkan; riwayat pelayanan, pesan grup dan
 * catatan paroki tetap ada dengan nama "Pengguna terhapus". Akun tidak dapat login atau memakai token lamanya lagi.
 */
@Injectable()
export class AccountDeletionService {
  constructor(
    @InjectDataSource() private readonly dataSource: DataSource,
    private readonly accounts: AccountStatusService,
  ) {}

  async deleteOwnAccount(
    userId: number,
    password: string,
  ): Promise<{ success: true; message: string }> {
    await this.dataSource.transaction(async (tx) => {
      const rows: {
        phone_number: string;
        password_hash: string;
        deleted_at: Date | null;
        role_code: string;
      }[] = await tx.query(
        `SELECT u.id, u.phone_number, u.password_hash, u.deleted_at, r.code AS role_code
         FROM auth_users u JOIN roles r ON r.id = u.role_id WHERE u.id = $1 FOR UPDATE OF u`,
        [userId],
      );
      const user = rows[0];
      if (!user || user.deleted_at)
        throw new NotFoundException('Akun tidak ditemukan');
      if (ADMIN_ROLES.includes(user.role_code))
        throw new ForbiddenException(
          'Akun admin tidak dapat dihapus dari aplikasi.',
        );
      if (!password || !(await bcrypt.compare(password, user.password_hash)))
        throw new BadRequestException('Kata sandi salah');
      await this.assertNoActiveService(tx, userId);
      await this.anonymize(tx, userId, user.phone_number);
    });
    this.accounts.invalidate(userId);
    return { success: true, message: 'Akun Anda telah dihapus.' };
  }

  private async assertNoActiveService(
    tx: EntityManager,
    userId: number,
  ): Promise<void> {
    const [own]: { n: number }[] = await tx.query(
      `SELECT COUNT(*)::int AS n FROM orders WHERE user_id = $1 AND status::text = ANY($2)`,
      [userId, ACTIVE_ORDER_STATUSES],
    );
    if (own.n > 0) {
      throw new ConflictException(
        `Masih ada ${own.n} pelayanan yang berjalan. Batalkan atau tunggu sampai selesai sebelum menghapus akun.`,
      );
    }
    const [served]: { n: number }[] = await tx.query(
      `SELECT COUNT(DISTINCT o.id)::int AS n FROM orders o
       LEFT JOIN order_items oi ON oi.order_id = o.id
       WHERE (o.accepted_romo_id = $1 AND o.status::text = ANY($2)) OR (oi.accepted_romo_id = $1 AND oi.status::text = ANY($2))`,
      [userId, ACTIVE_ORDER_STATUSES],
    );
    if (served.n > 0) {
      throw new ConflictException(
        `Anda masih melayani ${served.n} pelayanan yang berjalan. Selesaikan atau serahkan ke Romo lain sebelum menghapus akun.`,
      );
    }
  }

  private async anonymize(
    tx: EntityManager,
    userId: number,
    phone: string,
  ): Promise<void> {
    await tx.query(
      // Status REJECTED + is_active false: semua pencarian Romo/Pengurus/penyetuju (account_status = 'APPROVED') melewatinya.
      `UPDATE auth_users SET phone_number = $2, password_hash = '!deleted', is_active = false, deleted_at = now(), account_status = 'REJECTED',
              approval_assigned_to_user_id = NULL, updated_at = now() WHERE id = $1`,
      [userId, deletedPhoneNumber(userId)],
    );
    await tx.query(
      `UPDATE user_profiles SET full_name = $2, email = NULL, birth_date = NULL, address = NULL, avatar_url = NULL,
              gender = NULL, updated_at = now() WHERE user_id = $1`,
      [userId, DELETED_USER_NAME],
    );
    await tx.query(
      `UPDATE activity_logs SET user_name = $2, ip_address = NULL, user_agent = NULL WHERE user_id = $1`,
      [userId, DELETED_USER_NAME],
    );
    // Undangan pelayanan yang belum dijawab dianggap ditolak agar pelayanan segera dialihkan ke Romo lain.
    await tx.query(
      `UPDATE order_assignments SET status = 'DECLINED', decline_reason = 'Akun Romo dihapus', responded_at = now()
       WHERE romo_id = $1 AND status = 'WAITING'`,
      [userId],
    );
    await tx.query(
      `DELETE FROM region_transfer_requests WHERE user_id = $1 AND status = 'PENDING'`,
      [userId],
    );
    for (const table of [
      'user_devices',
      'notifications',
      'news_bookmarks',
      'auth_login_links',
      'chat_message_reads',
      'chat_group_members',
    ]) {
      await tx.query(`DELETE FROM ${table} WHERE user_id = $1`, [userId]);
    }
    await tx.query(`DELETE FROM otp_codes WHERE phone_number = $1`, [phone]);
  }
}
