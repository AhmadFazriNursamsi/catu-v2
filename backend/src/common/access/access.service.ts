import { ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { InjectDataSource } from '@nestjs/typeorm';
import { DataSource } from 'typeorm';
import { ADMIN_ROLES, STAFF_ROLES } from './role-groups';

/** Payload JWT yang di-attach oleh JwtAuthGuard pada request.user (class agar kompatibel dengan metadata decorator). */
export class AuthUser {
  sub!: number;
  roleCode!: string;
}

@Injectable()
export class AccessService {
  constructor(@InjectDataSource() private readonly dataSource: DataSource) {}

  isAdmin(user: AuthUser): boolean {
    return ADMIN_ROLES.includes(user.roleCode);
  }

  /** Umat (UMAT, UMAT_PENDATANG, dan peran umat lain) = bukan staf; datanya dibatasi ke milik sendiri. */
  isEndUser(user: AuthUser): boolean {
    return !STAFF_ROLES.includes(user.roleCode);
  }

  /** Pengguna hanya boleh bertindak atas dirinya sendiri (admin dikecualikan). */
  assertSelf(user: AuthUser, targetUserId: unknown): void {
    if (this.isAdmin(user)) return;
    if (Number(targetUserId) !== Number(user.sub)) {
      throw new ForbiddenException('Akses ditolak: Anda hanya dapat mengakses data milik sendiri');
    }
  }

  /** Umat hanya boleh melihat order miliknya; peran pelayanan/pengurus/admin dilayani sesuai scope. */
  async assertOrderAccess(user: AuthUser, orderIdParam: string | number): Promise<void> {
    if (!this.isEndUser(user)) return;
    const orderId = parseInt(String(orderIdParam), 10) || 0;
    const rows = await this.dataSource.query('SELECT user_id FROM orders WHERE id = $1', [orderId]);
    if (rows.length === 0) throw new NotFoundException('Order tidak ditemukan');
    if (Number(rows[0].user_id) !== Number(user.sub)) {
      throw new ForbiddenException('Akses ditolak: order ini bukan milik Anda');
    }
  }

  async assertNotificationOwner(user: AuthUser, notificationId: number): Promise<void> {
    if (this.isAdmin(user)) return;
    const rows = await this.dataSource.query('SELECT user_id FROM notifications WHERE id = $1', [
      notificationId,
    ]);
    if (rows.length === 0) return;
    if (Number(rows[0].user_id) !== Number(user.sub)) {
      throw new ForbiddenException('Akses ditolak: notifikasi ini bukan milik Anda');
    }
  }
}
