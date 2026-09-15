import {
  Injectable,
  BadRequestException,
  NotFoundException,
} from "@nestjs/common";
import { InjectDataSource } from "@nestjs/typeorm";
import { DataSource } from "typeorm";
import { SendChatMessageDto } from "../../orders.dto";
import { FcmService } from "../../fcm.service";

@Injectable()
export class ChatService {
  constructor(
    @InjectDataSource() private readonly dataSource: DataSource,
    private readonly fcmService: FcmService,
  ) {}
private async resolveGroupId(idParam: string): Promise<number> {
    const num = parseInt(idParam, 10) || 0;
    if (num <= 0) return 1;

    // 1. Check if chat_groups row exists with id = num or order_id = num
    const existing = await this.dataSource.query(
      `SELECT id FROM chat_groups WHERE id = $1 OR order_id = $1 ORDER BY (id = $1) DESC LIMIT 1`,
      [num],
    );

    if (existing.length > 0) {
      return existing[0].id;
    }

    // 2. If no chat_groups row exists, but an order with id = num exists, auto-create chat_groups for that order
    const orderCheck = await this.dataSource.query(
      `SELECT o.id, sc.name as category_name
       FROM orders o
       JOIN service_categories sc ON o.service_category_id = sc.id
       WHERE o.id = $1`,
      [num],
    );

    if (orderCheck.length > 0) {
      const order = orderCheck[0];
      const created = await this.dataSource.query(
        `INSERT INTO chat_groups (order_id, title, last_message_text)
         VALUES ($1, $2, $3) RETURNING id`,
        [order.id, `Group Pelayanan ${order.category_name || 'Umat'}`, 'Grup chat pelayanan telah dibentuk.'],
      );
      if (created.length > 0) {
        await this.dataSource.query(
          `INSERT INTO chat_messages (chat_group_id, sender_id, message_type, message) VALUES ($1, NULL, 'SYSTEM_EVENT', $2)`,
          [created[0].id, 'Grup chat pelayanan telah otomatis dibentuk oleh sistem.'],
        );
        return created[0].id;
      }
    }

    return num;
  }
  async getGroupByOrderId(orderIdParam: string) {
    const orderId = parseInt(orderIdParam, 10) || 0;
    if (orderId <= 0) return { groupId: 1 };

    const existing = await this.dataSource.query(
      `SELECT id FROM chat_groups WHERE order_id = $1 LIMIT 1`,
      [orderId],
    );

    if (existing.length > 0) {
      return { groupId: existing[0].id };
    }

    const orderCheck = await this.dataSource.query(
      `SELECT o.id, sc.name as category_name, o.order_number
       FROM orders o
       JOIN service_categories sc ON o.service_category_id = sc.id
       WHERE o.id = $1`,
      [orderId],
    );

    if (orderCheck.length > 0) {
      const order = orderCheck[0];
      const created = await this.dataSource.query(
        `INSERT INTO chat_groups (order_id, title, last_message_text)
         VALUES ($1, $2, $3) RETURNING id`,
        [order.id, `Grup Pelayanan - ${order.order_number || order.category_name}`, 'Grup chat pelayanan aktif'],
      );
      if (created.length > 0) {
        return { groupId: created[0].id };
      }
    }

    return { groupId: orderId };
  }

  async sendMessage(
    groupIdParam: string,
    dto: SendChatMessageDto,
  ) {
    const groupId = await this.resolveGroupId(groupIdParam);
    const senderId = dto.senderId || 1;

    const msgText = (dto.message && dto.message.trim().length > 0)
      ? dto.message
      : (dto.messageType === 'IMAGE' ? 'Foto' : (dto.messageType === 'LOCATION' ? 'Lokasi' : 'Pesan'));

    const result = await this.dataSource.query(
      `INSERT INTO chat_messages (chat_group_id, sender_id, message_type, message, attachment_url)
       VALUES ($1, $2, $3::chat_message_type_enum, $4, $5) RETURNING id, chat_group_id, sender_id, message_type, message, attachment_url, created_at`,
      [groupId, senderId, dto.messageType, msgText, dto.attachmentUrl || null],
    );

    await this.dataSource.query(
      `UPDATE chat_groups SET last_message_text = $1, last_message_at = CURRENT_TIMESTAMP WHERE id = $2`,
      [dto.messageType === 'IMAGE' ? '📷 Foto' : msgText, groupId],
    );

    if (result.length > 0 && result[0].id) {
      await this.dataSource.query(
        `INSERT INTO chat_group_members (chat_group_id, user_id, role_in_group, last_read_message_id)
         VALUES ($1, $2, 'MEMBER', $3)
         ON CONFLICT (chat_group_id, user_id)
         DO UPDATE SET last_read_message_id = GREATEST(COALESCE(chat_group_members.last_read_message_id, 0), $3)`,
        [groupId, senderId, result[0].id],
      );
    }

    // 🔔 Notify other group members
    try {
      const senderProfile = await this.dataSource.query(
        `SELECT full_name FROM user_profiles WHERE user_id = $1`,
        [senderId],
      );
      const senderName = senderProfile[0]?.full_name || 'Seseorang';

      const groupInfo = await this.dataSource.query(
        `SELECT g.id, g.title, g.order_id, o.order_number, sc.name as category_name,
                COALESCE(oi.item_name, sc.name) as item_name,
                p.full_name as penerima_name, o.user_id as order_creator_id
         FROM chat_groups g
         LEFT JOIN orders o ON g.order_id = o.id
         LEFT JOIN service_categories sc ON o.service_category_id = sc.id
         LEFT JOIN order_items oi ON g.order_item_id = oi.id
         LEFT JOIN user_profiles p ON o.user_id = p.user_id
         WHERE g.id = $1`,
        [groupId],
      );
      const orderId = groupInfo[0]?.order_id || null;
      const orderNumber = groupInfo[0]?.order_number || (orderId ? `ORD-${orderId}` : '');
      const categoryName = groupInfo[0]?.category_name || '';
      const itemTitle = groupInfo[0]?.item_name || '';
      const penerimaName = groupInfo[0]?.penerima_name || '';

      const members = await this.dataSource.query(
        `SELECT DISTINCT user_id FROM chat_group_members WHERE chat_group_id = $1 AND user_id != $2 AND user_id IS NOT NULL`,
        [groupId, senderId],
      );

      const targetUserIds: number[] = [];
      const msgBody = dto.messageType === 'IMAGE'
        ? '📷 Mengirim gambar'
        : (dto.messageType === 'LOCATION' ? '📍 Berbagi lokasi' : (dto.message || 'Pesan baru'));

      for (const m of members) {
        if (m.user_id && Number(m.user_id) !== Number(senderId) && !targetUserIds.includes(Number(m.user_id))) {
          targetUserIds.push(Number(m.user_id));
        }
      }

      if (orderId) {
        const orderCreatorId = groupInfo[0]?.order_creator_id;
        if (orderCreatorId && Number(orderCreatorId) !== Number(senderId) && !targetUserIds.includes(Number(orderCreatorId))) {
          targetUserIds.push(Number(orderCreatorId));
        }

        const assignments = await this.dataSource.query(
          `SELECT romo_id FROM order_assignments WHERE order_id = $1 AND romo_id IS NOT NULL`,
          [orderId],
        );
        for (const a of assignments) {
          if (a.romo_id && Number(a.romo_id) !== Number(senderId) && !targetUserIds.includes(Number(a.romo_id))) {
            targetUserIds.push(Number(a.romo_id));
          }
        }
      }

      // 1. Insert into notifications table for instant sync across all platforms / simulators
      for (const targetId of targetUserIds) {
        await this.dataSource.query(
          `INSERT INTO notifications (user_id, order_id, chat_group_id, title, body, type, is_read)
           VALUES ($1, $2, $3, $4, $5, 'CHAT_MESSAGE', FALSE)`,
          [
            targetId,
            orderId,
            groupId,
            `Pesan dari ${senderName}`,
            msgBody,
          ],
        );
      }

      // 2. Dispatch FCM push notification
      if (targetUserIds.length > 0) {
        await this.fcmService.sendPushToUsers(targetUserIds, {
          title: `Pesan dari ${senderName}`,
          body: msgBody,
          data: {
            type: 'CHAT_MESSAGE',
            groupId: groupId.toString(),
            orderId: orderId ? orderId.toString() : '',
            orderNumber: orderNumber,
            categoryName: categoryName,
            itemTitle: itemTitle,
            penerimaName: penerimaName,
          },
        });
      }
    } catch (e) {
      console.error('Error dispatching chat notification:', e);
    }

    return {
      message: 'Pesan berhasil terkirim ke Group Chat!',
      data: result[0],
    };
  }
  async markGroupAsRead(
    groupIdParam: string,
    body: { userId?: number },
    queryUserId?: string,
  ) {
    const groupId = await this.resolveGroupId(groupIdParam);
    const userId = body?.userId || parseInt(queryUserId || '', 10) || 1;

    const maxMsg = await this.dataSource.query(
      `SELECT COALESCE(MAX(id), 0) as max_id FROM chat_messages WHERE chat_group_id = $1`,
      [groupId],
    );
    const maxId = maxMsg[0]?.max_id || 0;

    if (maxId > 0 && userId > 0) {
      await this.dataSource.query(
        `INSERT INTO chat_group_members (chat_group_id, user_id, role_in_group, last_read_message_id)
         VALUES ($1, $2, 'MEMBER', $3)
         ON CONFLICT (chat_group_id, user_id)
         DO UPDATE SET last_read_message_id = GREATEST(COALESCE(chat_group_members.last_read_message_id, 0), $3)`,
        [groupId, userId, maxId],
      );
      await this.dataSource.query(
        `UPDATE notifications SET is_read = TRUE
         WHERE user_id = $1 AND (chat_group_id = $2 OR (order_id = (SELECT order_id FROM chat_groups WHERE id = $2) AND type = 'CHAT_MESSAGE'))`,
        [userId, groupId],
      );
    }

    return { success: true, groupId, userId, lastReadMessageId: maxId };
  }
  async getMessages(
    groupIdParam: string,
    userIdParam?: string,
  ) {
    const groupId = await this.resolveGroupId(groupIdParam);

    if (userIdParam) {
      const uId = parseInt(userIdParam, 10) || 0;
      if (uId > 0) {
        const maxMsg = await this.dataSource.query(
          `SELECT COALESCE(MAX(id), 0) as max_id FROM chat_messages WHERE chat_group_id = $1`,
          [groupId],
        );
        const maxId = maxMsg[0]?.max_id || 0;
        if (maxId > 0) {
          try {
            await this.dataSource.query(
              `INSERT INTO chat_group_members (chat_group_id, user_id, role_in_group, last_read_message_id)
               VALUES ($1, $2, 'MEMBER', $3)
               ON CONFLICT (chat_group_id, user_id)
               DO UPDATE SET last_read_message_id = GREATEST(COALESCE(chat_group_members.last_read_message_id, 0), $3)`,
              [groupId, uId, maxId],
            );
            await this.dataSource.query(
              `UPDATE notifications SET is_read = TRUE
               WHERE user_id = $1 AND (chat_group_id = $2 OR (order_id = (SELECT order_id FROM chat_groups WHERE id = $2) AND type = 'CHAT_MESSAGE'))`,
              [uId, groupId],
            );
          } catch (readReceiptErr) {
            // Non-blocking: background read receipt failure should never fail message retrieval
          }
        }
      }
    }

    return await this.dataSource.query(
      `SELECT m.id, m.chat_group_id, m.sender_id, p.full_name as sender_name, m.message_type, m.message, m.attachment_url, m.created_at
       FROM chat_messages m
       LEFT JOIN user_profiles p ON m.sender_id = p.user_id
       WHERE m.chat_group_id = $1
       ORDER BY m.id ASC`,
      [groupId],
    );
  }
  async getGroupDetail(
    groupIdParam: string,
    queryUserId?: string,
  ) {
    const groupId = await this.resolveGroupId(groupIdParam);
    const userId = parseInt(queryUserId || '', 10) || 1;

    const result = await this.dataSource.query(
      `SELECT g.id as group_id, g.order_id, g.order_item_id as order_item_id, o.order_number, g.title as group_title,
              COALESCE(
                (SELECT message FROM chat_messages m WHERE m.chat_group_id = g.id AND m.message_type != 'SYSTEM_EVENT' ORDER BY m.id DESC LIMIT 1),
                g.last_message_text,
                'Grup chat pelayanan aktif'
              ) as last_message_text,
              (SELECT m.sender_id FROM chat_messages m WHERE m.chat_group_id = g.id AND m.message_type != 'SYSTEM_EVENT' ORDER BY m.id DESC LIMIT 1) as last_sender_id,
              (SELECT COALESCE(p.full_name, 'Pengguna') FROM chat_messages m LEFT JOIN user_profiles p ON m.sender_id = p.user_id WHERE m.chat_group_id = g.id AND m.message_type != 'SYSTEM_EVENT' ORDER BY m.id DESC LIMIT 1) as last_sender_name,
              COALESCE(
                (SELECT created_at FROM chat_messages m WHERE m.chat_group_id = g.id ORDER BY m.id DESC LIMIT 1),
                g.last_message_at,
                o.created_at
              ) as last_message_at,
              COALESCE(
                oi.item_name,
                (SELECT sub_oi.item_name FROM order_items sub_oi WHERE sub_oi.order_id = o.id ORDER BY sub_oi.id ASC LIMIT 1),
                sc.name
              ) as order_title,
              sc.name as order_category,
              COALESCE(oi.status, o.status::text) as order_status,
              COALESCE(oi.scheduled_date::text, o.scheduled_date::text) as scheduled_date,
              COALESCE(oi.scheduled_time_start::text, o.scheduled_time::text) as scheduled_time_start,
              COALESCE(oi.scheduled_time_end::text, '') as scheduled_time_end,
              o.notes, ul.name as urgency_name, p.full_name as penerima_name,
              p.full_name as requester_name, p.avatar_url as requester_avatar,
              COALESCE(
                (
                  SELECT COUNT(*)::int
                  FROM chat_messages m
                  WHERE m.chat_group_id = g.id
                    AND (m.sender_id IS NOT NULL AND m.sender_id != $2)
                    AND m.message_type != 'SYSTEM_EVENT'
                    AND m.id > COALESCE(
                      (SELECT cgm.last_read_message_id FROM chat_group_members cgm WHERE cgm.chat_group_id = g.id AND cgm.user_id = $2),
                      0
                    )
                ),
                0
              ) as unread_count
       FROM chat_groups g
       JOIN orders o ON g.order_id = o.id
       JOIN service_categories sc ON o.service_category_id = sc.id
       LEFT JOIN order_items oi ON g.order_item_id = oi.id
       LEFT JOIN urgency_levels ul ON o.urgency_level_id = ul.id
       LEFT JOIN user_profiles p ON o.user_id = p.user_id
       WHERE g.id = $1
       LIMIT 1`,
      [groupId, userId],
    );

    if (!result || result.length === 0) {
      throw new NotFoundException(`Chat group with ID ${groupId} not found`);
    }

    return result[0];
  }
  async getGroupMembers(groupIdParam: string) {
    const groupId = await this.resolveGroupId(groupIdParam);

    // Fetch order details to check status, lingkungan_id, paroki_id, accepted_romo_id
    const orderRes = await this.dataSource.query(
      `SELECT o.id as order_id,
              COALESCE(oi.status, o.status::text) as status,
              o.user_id as pemohon_id,
              COALESCE(oi.accepted_romo_id, o.accepted_romo_id) as accepted_romo_id,
              COALESCE(o.lingkungan_id, p.lingkungan_id) as lingkungan_id,
              COALESCE(o.paroki_id, p.paroki_id) as paroki_id,
              p.full_name as pemohon_name, u.phone_number as pemohon_phone,
              l.name as lingkungan_name, par.name as paroki_name
       FROM chat_groups g
       JOIN orders o ON g.order_id = o.id
       LEFT JOIN order_items oi ON g.order_item_id = oi.id
       JOIN auth_users u ON o.user_id = u.id
       LEFT JOIN user_profiles p ON o.user_id = p.user_id
       LEFT JOIN lingkungan l ON COALESCE(o.lingkungan_id, p.lingkungan_id) = l.id
       LEFT JOIN paroki par ON COALESCE(o.paroki_id, p.paroki_id) = par.id
       WHERE g.id = $1`,
      [groupId],
    );

    if (orderRes.length === 0) {
      return [];
    }

    const order = orderRes[0];
    const isRomoAccepted = order.status !== 'PENDING' && order.accepted_romo_id != null;

    const memberList: any[] = [];

    // 1. Pemohon (Umat)
    memberList.push({
      user_id: order.pemohon_id,
      role_in_group: 'PEMOHON',
      full_name: order.pemohon_name || 'Umat Pemohon',
      phone_number: order.pemohon_phone || '-',
      lingkungan_name: order.lingkungan_name ? `Lingkungan ${order.lingkungan_name}` : (order.paroki_name || 'Umat Paroki'),
    });

    // 2. Pengurus Lingkungan (from same lingkungan or paroki)
    let pengurus: any[] = [];
    if (order.lingkungan_id) {
      pengurus = await this.dataSource.query(
        `SELECT u.id as user_id, 'PENGURUS_LINGKUNGAN' as role_in_group, p.full_name, u.phone_number,
                COALESCE(l.name, 'Lingkungan') as lingkungan_name
         FROM auth_users u
         JOIN user_profiles p ON u.id = p.user_id
         JOIN roles r ON u.role_id = r.id
         LEFT JOIN lingkungan l ON p.lingkungan_id = l.id
         WHERE (r.code = 'PENGURUS_LINGKUNGAN' OR p.pengurus_position IS NOT NULL) AND p.lingkungan_id = $1
         ORDER BY u.id ASC`,
        [order.lingkungan_id],
      );
    }
    if (pengurus.length === 0 && order.paroki_id) {
      pengurus = await this.dataSource.query(
        `SELECT u.id as user_id, 'PENGURUS_LINGKUNGAN' as role_in_group, p.full_name, u.phone_number,
                COALESCE(l.name, 'Lingkungan') as lingkungan_name
         FROM auth_users u
         JOIN user_profiles p ON u.id = p.user_id
         JOIN roles r ON u.role_id = r.id
         LEFT JOIN lingkungan l ON p.lingkungan_id = l.id
         WHERE (r.code = 'PENGURUS_LINGKUNGAN' OR p.pengurus_position IS NOT NULL) AND p.paroki_id = $1
         ORDER BY u.id ASC`,
        [order.paroki_id],
      );
    }

    for (const p of pengurus) {
      if (!memberList.some((m: any) => m.user_id === p.user_id)) {
        memberList.push({
          user_id: p.user_id,
          role_in_group: 'PENGURUS_LINGKUNGAN',
          full_name: p.full_name || 'Pengurus Lingkungan',
          phone_number: p.phone_number || '-',
          lingkungan_name: p.lingkungan_name ? `Pengurus Lingkungan ${p.lingkungan_name}` : 'Pengurus Lingkungan',
        });
      }
    }

    // 2b. Koordinator Keuskupan
    const keuskupanId = order.keuskupan_id || (
      await this.dataSource.query('SELECT keuskupan_id FROM user_profiles WHERE user_id = $1', [order.pemohon_id])
    )[0]?.keuskupan_id;

    if (keuskupanId) {
      const koordinator = await this.dataSource.query(
        `SELECT u.id as user_id, 'KOORDINATOR' as role_in_group, p.full_name, u.phone_number,
                COALESCE(k.name, 'Keuskupan') as keuskupan_name
         FROM auth_users u
         JOIN user_profiles p ON u.id = p.user_id
         JOIN roles r ON u.role_id = r.id
         LEFT JOIN keuskupan k ON p.keuskupan_id = k.id
         WHERE (r.code = 'KOORDINATOR' OR LOWER(p.pengurus_position) LIKE '%koordinator%') AND p.keuskupan_id = $1
         ORDER BY u.id ASC`,
        [keuskupanId],
      );

      for (const k of koordinator) {
        if (!memberList.some((m: any) => m.user_id === k.user_id)) {
          memberList.push({
            user_id: k.user_id,
            role_in_group: 'KOORDINATOR',
            full_name: k.full_name || 'Koordinator Keuskupan',
            phone_number: k.phone_number || '-',
            lingkungan_name: k.keuskupan_name ? `Koordinator ${k.keuskupan_name}` : 'Koordinator Keuskupan',
          });
        }
      }
    }

    // 3. Romo (ONLY IF accepted and status != PENDING)
    if (isRomoAccepted) {
      const romoRes = await this.dataSource.query(
        `SELECT u.id as user_id, r.code as role_code, p.full_name, u.phone_number, par.name as paroki_name
         FROM auth_users u
         JOIN user_profiles p ON u.id = p.user_id
         JOIN roles r ON u.role_id = r.id
         LEFT JOIN paroki par ON p.paroki_id = par.id
         WHERE u.id = $1`,
        [order.accepted_romo_id],
      );
      if (romoRes.length > 0) {
        const romo = romoRes[0];
        memberList.push({
          user_id: romo.user_id,
          role_in_group: romo.role_code === 'ROMO_ORDO' ? 'ROMO_ORDO' : 'ROMO_PAROKI',
          full_name: romo.full_name || 'Romo Pelayan',
          phone_number: romo.phone_number || '-',
          lingkungan_name: romo.paroki_name ? `Romo ${romo.paroki_name}` : 'Romo Pelayan',
        });
      }
    }

    return memberList;
  }
  async getUserChatGroups(userId: string) {
    const parsedUId = parseInt(userId, 10) || 0;
    const userProf = await this.dataSource.query(
      `SELECT u.id, r.code as role_code, p.paroki_id, p.kabupaten_kota_id
       FROM auth_users u
       JOIN roles r ON u.role_id = r.id
       LEFT JOIN user_profiles p ON p.user_id = u.id
       WHERE u.id = $1`,
      [parsedUId],
    );

    let whereClause = '';
    const queryParams: any[] = [parsedUId];
    if (userProf.length > 0) {
      const user = userProf[0];
      if (user.role_code === 'ADMIN') {
        whereClause = '';
      } else if (user.role_code.startsWith('ROMO')) {
        whereClause = `WHERE (
          EXISTS (SELECT 1 FROM chat_group_members cgm WHERE cgm.chat_group_id = g.id AND cgm.user_id = $1)
        )`;
      } else {
        whereClause = `WHERE (o.user_id = $1 OR EXISTS (SELECT 1 FROM chat_group_members cgm WHERE cgm.chat_group_id = g.id AND cgm.user_id = $1))`;
      }
    }

    const result = await this.dataSource.query(
      `SELECT g.id as group_id, g.order_id, g.order_item_id as order_item_id, o.order_number, g.title as group_title,
              COALESCE(
                (SELECT message FROM chat_messages m WHERE m.chat_group_id = g.id AND m.message_type != 'SYSTEM_EVENT' ORDER BY m.id DESC LIMIT 1),
                g.last_message_text,
                'Grup chat pelayanan aktif'
              ) as last_message_text,
              (SELECT m.sender_id FROM chat_messages m WHERE m.chat_group_id = g.id AND m.message_type != 'SYSTEM_EVENT' ORDER BY m.id DESC LIMIT 1) as last_sender_id,
              (SELECT COALESCE(p.full_name, 'Pengguna') FROM chat_messages m LEFT JOIN user_profiles p ON m.sender_id = p.user_id WHERE m.chat_group_id = g.id AND m.message_type != 'SYSTEM_EVENT' ORDER BY m.id DESC LIMIT 1) as last_sender_name,
              COALESCE(
                (SELECT created_at FROM chat_messages m WHERE m.chat_group_id = g.id ORDER BY m.id DESC LIMIT 1),
                g.last_message_at,
                o.created_at
              ) as last_message_at,
              COALESCE(
                oi.item_name,
                (SELECT sub_oi.item_name FROM order_items sub_oi WHERE sub_oi.order_id = o.id ORDER BY sub_oi.id ASC LIMIT 1),
                sc.name
              ) as order_title,
              sc.name as order_category,
              COALESCE(oi.status, o.status::text) as order_status,
              COALESCE(oi.scheduled_date::text, o.scheduled_date::text) as scheduled_date,
              COALESCE(oi.scheduled_time_start::text, o.scheduled_time::text) as scheduled_time_start,
              COALESCE(oi.scheduled_time_end::text, '') as scheduled_time_end,
              o.notes, ul.name as urgency_name, p.full_name as penerima_name,
              p.full_name as requester_name,
              CASE WHEN LENGTH(p.avatar_url) > 500 THEN NULL ELSE p.avatar_url END as requester_avatar,
              COALESCE(
                (
                  SELECT COUNT(*)::int
                  FROM chat_messages m
                  WHERE m.chat_group_id = g.id
                    AND (m.sender_id IS NOT NULL AND m.sender_id != $1)
                    AND m.message_type != 'SYSTEM_EVENT'
                    AND m.id > COALESCE(
                      (SELECT cgm.last_read_message_id FROM chat_group_members cgm WHERE cgm.chat_group_id = g.id AND cgm.user_id = $1),
                      0
                    )
                ),
                0
              ) as unread_count
       FROM chat_groups g
       JOIN orders o ON g.order_id = o.id
       JOIN service_categories sc ON o.service_category_id = sc.id
       LEFT JOIN order_items oi ON g.order_item_id = oi.id
       LEFT JOIN urgency_levels ul ON o.urgency_level_id = ul.id
       LEFT JOIN user_profiles p ON o.user_id = p.user_id
       ${whereClause}
       ORDER BY COALESCE(g.last_message_at, o.created_at) DESC, g.id DESC`,
      queryParams,
    );
    return result;
  }
  async getAllChatGroups() {
    return await this.getUserChatGroups('1');
  }
}
