import { Injectable } from '@nestjs/common';
import { InjectDataSource } from '@nestjs/typeorm';
import { DataSource } from 'typeorm';
import { FcmService } from '../../fcm.service';

@Injectable()
export class NotificationsService {
  constructor(
    @InjectDataSource() private readonly dataSource: DataSource,
    private readonly fcmService: FcmService,
  ) {}

  async registerDevice(body: {
    userId: number;
    fcmToken: string;
    deviceType?: string;
    deviceModel?: string;
  }) {
    if (!body.userId || !body.fcmToken) {
      return { success: false, message: 'userId and fcmToken are required' };
    }
    return await this.fcmService.registerDeviceToken(
      body.userId,
      body.fcmToken,
      body.deviceType || 'ANDROID',
      body.deviceModel,
    );
  }

  async unregisterDevice(body: { userId: number; fcmToken: string }) {
    if (!body.userId || !body.fcmToken) {
      return { success: false, message: 'userId and fcmToken are required' };
    }
    return await this.fcmService.unregisterDeviceToken(body.userId, body.fcmToken);
  }

  async testPush(body: { userId: number; title?: string; message?: string }) {
    if (!body.userId) {
      return { success: false, message: 'userId is required' };
    }
    const res = await this.fcmService.sendPushToUsers(body.userId, {
      title: body.title || '🔔 Tes Notifikasi CATU',
      body:
        body.message ||
        'Push notification Firebase FCM berhasil terhubung dengan server CATU!',
      data: { type: 'TEST_PUSH', timestamp: new Date().toISOString() },
    });
    return { success: true, result: res };
  }

  async getNotifications(userId?: string, role?: string) {
    const whereClauses: string[] = [];
    const queryParams: any[] = [];
    let idx = 1;

    if (userId && !isNaN(parseInt(userId, 10))) {
      whereClauses.push(`n.user_id = $${idx++}`);
      queryParams.push(parseInt(userId, 10));
    }

    const whereStr =
      whereClauses.length > 0 ? `WHERE ${whereClauses.join(' AND ')}` : '';
    const query = `
      SELECT n.id, n.user_id as "userId", n.order_id as "orderId",
             COALESCE(n.chat_group_id, cg.id) as "groupId",
             n.title, n.body, n.type, n.is_read as "isRead", n.created_at as "createdAt",
             o.order_number as "orderNumber", sc.name as "categoryName",
             o.status as "orderStatus"
      FROM notifications n
      LEFT JOIN orders o ON n.order_id = o.id
      LEFT JOIN service_categories sc ON o.service_category_id = sc.id
      LEFT JOIN LATERAL (
        SELECT id FROM chat_groups WHERE order_id = n.order_id ORDER BY id ASC LIMIT 1
      ) cg ON n.chat_group_id IS NULL
      ${whereStr}
      ORDER BY n.id DESC LIMIT 100
    `;
    return await this.dataSource.query(query, queryParams);
  }

  async markRead(id: number) {
    if (!isNaN(id)) {
      await this.dataSource.query(
        'UPDATE notifications SET is_read = true WHERE id = $1',
        [id],
      );
    }
    return { success: true };
  }

  async markAllRead(userId: number) {
    if (userId) {
      await this.dataSource.query(
        'UPDATE notifications SET is_read = true WHERE user_id = $1',
        [userId],
      );
    }
    return { success: true };
  }

  async deleteNotification(id: number) {
    if (!isNaN(id)) {
      await this.dataSource.query('DELETE FROM notifications WHERE id = $1', [
        id,
      ]);
    }
    return { success: true };
  }
}
