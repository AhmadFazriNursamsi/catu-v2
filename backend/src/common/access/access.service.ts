import { ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { InjectDataSource } from '@nestjs/typeorm';
import { DataSource } from 'typeorm';
import { ADMIN_ROLES, STAFF_ROLES } from './role-groups';
import { orderKeuskupanSql } from '../../modules/order-rules/lintas-paroki';
import { PENGURUS_ROLE, pengurusMayViewOrder } from './order-visibility';

/** Payload JWT yang di-attach oleh JwtAuthGuard pada request.user (class agar kompatibel dengan metadata decorator). */
export class AuthUser {
  sub!: number;
  roleCode!: string;
  /** Diisi 'login-link' bila sesi berasal dari tautan masuk WhatsApp. */
  via?: string;
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
    const isPengurus = user.roleCode === PENGURUS_ROLE;
    if (!this.isEndUser(user) && !isPengurus) return;
    const orderId = parseInt(String(orderIdParam), 10) || 0;
    if (isPengurus) return this.assertPengurusOrderAccess(user, orderId);
    const rows = await this.dataSource.query('SELECT user_id FROM orders WHERE id = $1', [orderId]);
    if (rows.length === 0) throw new NotFoundException('Order tidak ditemukan');
    if (Number(rows[0].user_id) !== Number(user.sub)) {
      throw new ForbiddenException('Akses ditolak: order ini bukan milik Anda');
    }
  }

  /** Pengurus Lingkungan: hanya pelayanan miliknya atau yang berasal dari lingkungannya. */
  private async assertPengurusOrderAccess(user: AuthUser, orderId: number): Promise<void> {
    const rows = await this.dataSource.query(
      `SELECT o.user_id AS owner_id, COALESCE(o.lingkungan_id, p.lingkungan_id) AS order_lingkungan_id,
              (SELECT lingkungan_id FROM user_profiles WHERE user_id = $2) AS pengurus_lingkungan_id
       FROM orders o JOIN user_profiles p ON p.user_id = o.user_id WHERE o.id = $1`,
      [orderId, user.sub],
    );
    if (rows.length === 0) throw new NotFoundException('Order tidak ditemukan');
    const r = rows[0];
    const ok = pengurusMayViewOrder({
      pengurusId: Number(user.sub),
      pengurusLingkunganId: r.pengurus_lingkungan_id == null ? null : Number(r.pengurus_lingkungan_id),
      orderOwnerId: Number(r.owner_id),
      orderLingkunganId: r.order_lingkungan_id == null ? null : Number(r.order_lingkungan_id),
    });
    if (!ok) throw new ForbiddenException('Akses ditolak: pelayanan ini berada di luar lingkungan Anda');
  }

  /**
   * Koordinator hanya berwenang atas pelayanan di keuskupan umat pemohon (dan keuskupan tujuan bila lintas paroki).
   * [groupOrOrderId] boleh id grup chat atau id order (sama seperti resolusi id di ChatService).
   */
  async koordinatorSharesKeuskupan(koordinatorId: number, groupOrOrderId: string | number): Promise<boolean> {
    const id = parseInt(String(groupOrOrderId), 10) || 0;
    if (id <= 0) return false;
    const rows = await this.dataSource.query(
      `SELECT 1
       FROM (SELECT order_id FROM chat_groups WHERE id = $1 OR order_id = $1 ORDER BY (id = $1) DESC LIMIT 1) g
       JOIN user_profiles k ON k.user_id = $2
       WHERE k.keuskupan_id IS NOT NULL AND k.keuskupan_id IN (${orderKeuskupanSql('g.order_id')})`,
      [id, koordinatorId],
    );
    return rows.length > 0;
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
