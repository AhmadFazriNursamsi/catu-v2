import {
  Injectable,
  BadRequestException,
  NotFoundException,
} from "@nestjs/common";
import { InjectDataSource } from "@nestjs/typeorm";
import { DataSource } from "typeorm";
import { RespondOrderAssignmentDto } from "../../orders.dto";
import { FcmService } from "../../fcm.service";
import { orderStatusFromItemsSql } from "../order-rules/order-status-derive";

@Injectable()
export class AssignmentsService {
  constructor(
    @InjectDataSource() private readonly dataSource: DataSource,
    private readonly fcmService: FcmService,
  ) {}
private async getPengurusForOrder(orderId: number, excludeUserId?: number): Promise<any[]> {
    const orderHierarchy = await this.dataSource.query(
      `SELECT o.lingkungan_id, o.paroki_id, COALESCE(o.keuskupan_id, p.keuskupan_id) as keuskupan_id
       FROM orders o
       JOIN user_profiles p ON o.user_id = p.user_id
       WHERE o.id = $1`,
      [orderId],
    );
    if (orderHierarchy.length === 0) return [];
    const oh = orderHierarchy[0];
    const keuskupanId = oh.keuskupan_id;
    let pengurus: any[] = [];
    if (oh.lingkungan_id) {
      pengurus = await this.dataSource.query(
        `SELECT u.id FROM auth_users u
         JOIN user_profiles p ON u.id = p.user_id
         JOIN roles r ON u.role_id = r.id
         WHERE (r.code = 'PENGURUS_LINGKUNGAN' OR (p.pengurus_position IS NOT NULL AND LOWER(p.pengurus_position) NOT LIKE '%koordinator%')) AND p.lingkungan_id = $1`,
        [oh.lingkungan_id],
      );
    }
    if (pengurus.length === 0 && oh.paroki_id) {
      pengurus = await this.dataSource.query(
        `SELECT u.id FROM auth_users u
         JOIN user_profiles p ON u.id = p.user_id
         JOIN roles r ON u.role_id = r.id
         WHERE (r.code = 'PENGURUS_LINGKUNGAN' OR (p.pengurus_position IS NOT NULL AND LOWER(p.pengurus_position) NOT LIKE '%koordinator%')) AND p.paroki_id = $1`,
        [oh.paroki_id],
      );
    }

    if (excludeUserId) {
      pengurus = pengurus.filter((p: any) => p.id !== excludeUserId);
    }

    return pengurus;
  }
  async respondAssignment(
    orderIdParam: string,
    dto: RespondOrderAssignmentDto,
  ) {
    const orderId = parseInt(orderIdParam, 10) || 0;
    let romoId = dto.romoId ? dto.romoId : null;
    if (romoId) {
      const rCheck = await this.dataSource.query('SELECT id FROM auth_users WHERE id = $1', [romoId]);
      if (rCheck.length === 0) romoId = null;
    }
    const itemId = (dto as any).itemId || (dto as any).item_id;

    const validStatuses = ['CONFIRMED', 'IN_PROGRESS', 'DONE', 'CLOSE', 'FAIL'];
    const newStatus = dto.status === 'ACCEPTED' ? 'CONFIRMED' : dto.status;

    if (!validStatuses.includes(newStatus) && newStatus !== 'DECLINED') {
      return { message: 'Status tidak valid', status: newStatus };
    }

    if (newStatus === 'DECLINED') {
      return {
        message: `Romo${romoId ? ` (ID ${romoId})` : ''} menolak tugas pelayanan untuk Order ID ${orderId}`,
        status: 'DECLINED',
      };
    }

    const existingOrders = await this.dataSource.query(
      `SELECT id, status, accepted_romo_id FROM orders WHERE id = $1`,
      [orderId],
    );
    if (existingOrders.length === 0) {
      return { message: 'Order tidak ditemukan', status: 'FAIL' };
    }

    if (itemId) {
      const existingItems = await this.dataSource.query(
        `SELECT id, status, accepted_romo_id FROM order_items WHERE id = $1 AND order_id = $2`,
        [itemId, orderId],
      );
      if (existingItems.length > 0) {
        const itemAcceptedRomo = existingItems[0].accepted_romo_id;
        if (newStatus === 'CONFIRMED' && itemAcceptedRomo && romoId && Number(itemAcceptedRomo) !== Number(romoId)) {
          return { message: 'Pelayanan ini sudah diterima oleh Romo lain.', status: existingItems[0].status };
        }
        if ((newStatus === 'DONE' || newStatus === 'IN_PROGRESS') && itemAcceptedRomo && romoId && Number(itemAcceptedRomo) !== Number(romoId)) {
          return { message: 'Hanya Romo yang bertugas yang dapat menyelesaikan pelayanan ini.', status: existingItems[0].status };
        }
      }
    } else {
      const orderAcceptedRomo = existingOrders[0].accepted_romo_id;
      if (newStatus === 'CONFIRMED' && orderAcceptedRomo && romoId && Number(orderAcceptedRomo) !== Number(romoId)) {
        return { message: 'Pelayanan ini sudah diterima oleh Romo lain.', status: existingOrders[0].status };
      }
      if ((newStatus === 'DONE' || newStatus === 'IN_PROGRESS') && orderAcceptedRomo && romoId && Number(orderAcceptedRomo) !== Number(romoId)) {
        return { message: 'Hanya Romo yang bertugas yang dapat menyelesaikan pelayanan ini.', status: existingOrders[0].status };
      }
    }

    if (itemId) {
      if (newStatus === 'CONFIRMED') {
        await this.dataSource.query(
          `UPDATE order_items SET status = $1, accepted_romo_id = COALESCE($2::int, accepted_romo_id) WHERE id = $3 AND order_id = $4`,
          [newStatus, romoId, itemId, orderId],
        );
      } else {
        await this.dataSource.query(
          `UPDATE order_items SET status = $1 WHERE id = $2 AND order_id = $3`,
          [newStatus, itemId, orderId],
        );
      }

      // Status pelayanan induk mengikuti seluruh misanya, bukan hanya misa yang baru berubah.
      await this.dataSource.query(
        `UPDATE orders SET status = COALESCE(${orderStatusFromItemsSql('orders.id')}::order_status_enum, status) WHERE id = $1`,
        [orderId],
      );
    } else {
      await this.dataSource.query(
        `UPDATE orders SET status = $1, accepted_romo_id = COALESCE($2::int, accepted_romo_id) WHERE id = $3`,
        [newStatus, romoId, orderId],
      );
      await this.dataSource.query(
        `UPDATE order_items SET status = $1, accepted_romo_id = COALESCE($2::int, accepted_romo_id) WHERE order_id = $3`,
        [newStatus, romoId, orderId],
      );
    }

    const romoProf = romoId ? await this.dataSource.query(
      `SELECT full_name FROM user_profiles WHERE user_id = $1`,
      [romoId],
    ) : [];
    const romoName = romoProf.length > 0 ? romoProf[0].full_name : 'Romo';

    const statusMessages: Record<string, string> = {
      CONFIRMED: `Romo ${romoName} telah mengkonfirmasi kehadiran dan bergabung dalam grup chat.`,
      IN_PROGRESS: `Romo ${romoName} sedang menjalankan pelayanan.`,
      DONE: `Romo ${romoName} telah menyelesaikan pelayanan. Terima kasih.`,
      CLOSE: `Romo ${romoName} menutup pelayanan tanpa penyelesaian.`,
      FAIL: `Tidak ada Romo yang menerima pelayanan ini hingga melewati tanggal pelayanan.`,
    };

    let targetGroups: any[] = [];
    if (itemId) {
      targetGroups = await this.dataSource.query(
        `SELECT id FROM chat_groups WHERE order_id = $1 AND order_item_id = $2`,
        [orderId, itemId],
      );
    }
    if (targetGroups.length === 0) {
      targetGroups = await this.dataSource.query(
        `SELECT id FROM chat_groups WHERE order_id = $1`,
        [orderId],
      );
    }

    if (targetGroups.length > 0) {
      let romoRole = 'ROMO_PAROKI';
      if (romoId) {
        const rCheck = await this.dataSource.query(
          `SELECT r.code FROM auth_users u JOIN roles r ON u.role_id = r.id WHERE u.id = $1`,
          [romoId],
        );
        if (rCheck.length > 0 && rCheck[0].code === 'ROMO_ORDO') {
          romoRole = 'ROMO_ORDO';
        }
      }

      for (const grp of targetGroups) {
        if (newStatus === 'CONFIRMED' && romoId) {
          await this.dataSource.query(
            `INSERT INTO chat_group_members (chat_group_id, user_id, role_in_group) VALUES ($1, $2, $3) ON CONFLICT (chat_group_id, user_id) DO UPDATE SET role_in_group = $3`,
            [grp.id, romoId, romoRole],
          );
        }

        await this.dataSource.query(
          `INSERT INTO chat_messages (chat_group_id, sender_id, message_type, message) VALUES ($1, NULL, 'SYSTEM_EVENT', $2)`,
          [grp.id, statusMessages[newStatus] || `Status diubah menjadi ${newStatus}`],
        );
      }
    }

    // 🔔 Send Real-Time Notifications to Umat and Pengurus Lingkungan
    const orderDetailRes = await this.dataSource.query(
      `SELECT o.id, o.order_number, o.user_id, o.lingkungan_id, o.paroki_id, sc.name as category_name
       FROM orders o
       JOIN service_categories sc ON o.service_category_id = sc.id
       WHERE o.id = $1`,
      [orderId],
    );

    if (orderDetailRes.length > 0) {
      const orderInfo = orderDetailRes[0];
      let serviceTitle = orderInfo.category_name || 'Pelayanan';
      if (itemId) {
        const itemRes = await this.dataSource.query(
          `SELECT item_name FROM order_items WHERE id = $1`,
          [itemId],
        );
        if (itemRes.length > 0) {
          serviceTitle = itemRes[0].item_name;
        }
      }

      const pengurusStatusList = await this.getPengurusForOrder(orderId);

      // Notifikasi menaut ke grup chat misa yang berubah (grup pertama order bila tanpa misa), agar ketukan membuka misa yang tepat.
      const kinds: Record<string, { type: string; titleUmat: string; bodyUmat: string; bodyPengurus: string }> = {
        CONFIRMED: { type: 'ORDER_CONFIRMED', titleUmat: 'Pelayanan Dikonfirmasi', bodyUmat: `Romo ${romoName} telah mengkonfirmasi kehadiran untuk melayani ${serviceTitle} (${orderInfo.order_number}).`, bodyPengurus: `Romo ${romoName} telah mengkonfirmasi kehadiran untuk melayani ${serviceTitle} (${orderInfo.order_number}) bagi warga lingkungan Anda.` },
        IN_PROGRESS: { type: 'ORDER_IN_PROGRESS', titleUmat: 'Pelayanan Berlangsung', bodyUmat: `Romo ${romoName} sedang menjalankan pelayanan ${serviceTitle} (${orderInfo.order_number}).`, bodyPengurus: `Romo ${romoName} sedang menjalankan pelayanan ${serviceTitle} (${orderInfo.order_number}) bagi warga lingkungan Anda.` },
        DONE: { type: 'ORDER_DONE', titleUmat: 'Pelayanan Selesai', bodyUmat: `Pelayanan ${serviceTitle} (${orderInfo.order_number}) telah selesai dilaksanakan oleh Romo ${romoName}. Terima kasih atas partisipasi Anda.`, bodyPengurus: `Pelayanan ${serviceTitle} (${orderInfo.order_number}) telah selesai dilaksanakan oleh Romo ${romoName}.` },
      };
      const kind = kinds[newStatus];
      if (kind) {
        const recipients = [orderInfo.user_id, ...pengurusStatusList.map((p: any) => p.id)].filter((id: number) => id);
        for (const userId of recipients) {
          await this.dataSource.query(
            `INSERT INTO notifications (user_id, order_id, chat_group_id, title, body, type, is_read) VALUES ($1, $2, $3, $4, $5, $6, false)`,
            [userId, orderId, targetGroups[0]?.id ?? null, `${kind.titleUmat}: ${serviceTitle}`, userId === orderInfo.user_id ? kind.bodyUmat : kind.bodyPengurus, kind.type],
          );
        }
      }

      // 🔔 Dispatch Real-Time FCM Push to Umat & Pengurus
      try {
        const targetUserIds = Array.from(new Set([
          orderInfo.user_id,
          ...pengurusStatusList.map((p: any) => p.id),
        ])).filter((id: number) => id && id !== romoId);

        if (targetUserIds.length > 0) {
          const notifTitle = newStatus === 'CONFIRMED'
            ? `Pelayanan Dikonfirmasi: ${serviceTitle}`
            : (newStatus === 'DONE' ? `Pelayanan Selesai: ${serviceTitle}` : `Pelayanan: ${serviceTitle} (${newStatus})`);
          const notifBody = newStatus === 'CONFIRMED'
            ? `Romo ${romoName} telah mengkonfirmasi kehadiran untuk melayani ${serviceTitle} (${orderInfo.order_number}).`
            : (newStatus === 'DONE'
                ? `Pelayanan ${serviceTitle} (${orderInfo.order_number}) telah selesai dilaksanakan oleh Romo ${romoName}.`
                : `Status pelayanan ${serviceTitle} (${orderInfo.order_number}) diubah menjadi ${newStatus} oleh Romo ${romoName}.`);

          await this.fcmService.sendPushToUsers(targetUserIds, {
            title: notifTitle,
            body: notifBody,
            data: {
              type: newStatus === 'CONFIRMED' ? 'ORDER_CONFIRMED' : (newStatus === 'DONE' ? 'ORDER_DONE' : 'ORDER_STATUS_CHANGED'),
              orderId: orderId.toString(),
              orderNumber: orderInfo.order_number,
              categoryName: orderInfo.category_name,
              itemId: itemId ? String(itemId) : '',
            },
          });
        }
      } catch (fcmErr) {
        console.error('Error dispatching FCM in respondAssignment:', fcmErr);
      }
    }

    return {
      message: `Order ID ${orderId} status diperbarui menjadi ${newStatus}`,
      status: newStatus,
    };
  }
}
