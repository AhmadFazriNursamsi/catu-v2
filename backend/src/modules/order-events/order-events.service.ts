import { BadRequestException, ForbiddenException, Injectable, Logger } from '@nestjs/common';
import { InjectDataSource } from '@nestjs/typeorm';
import { DataSource } from 'typeorm';
import { FcmService } from '../../fcm.service';

/** Pengajuan ubah jam ditutup setelah ditolak sebanyak ini untuk satu pelayanan/misa. */
export const MAX_RESCHEDULE_REJECTIONS = 2;

export interface OrderNotification {
  orderId: number;
  itemId?: number | null;
  type: string;
  title: string;
  body: string;
}

/**
 * Titik tunggal untuk event pelayanan lintas-fitur: menulis pesan sistem ke grup chat yang benar
 * (grup milik misa/item bila ada) dan mengirim notifikasi yang membawa informasi misa tujuan.
 */
@Injectable()
export class OrderEventsService {
  private readonly logger = new Logger(OrderEventsService.name);

  constructor(
    @InjectDataSource() private readonly dataSource: DataSource,
    private readonly fcm: FcmService,
  ) {}

  /** Grup chat milik item; bila item tidak punya grup sendiri, grup pertama order. */
  async groupIdFor(orderId: number, itemId?: number | null): Promise<number | null> {
    const rows = await this.dataSource.query(
      `SELECT id FROM chat_groups WHERE order_id = $1
       ORDER BY (order_item_id IS NOT DISTINCT FROM $2::bigint) DESC, id ASC LIMIT 1`,
      [orderId, itemId || null],
    );
    return rows.length > 0 ? Number(rows[0].id) : null;
  }

  async itemName(orderId: number, itemId?: number | null): Promise<string> {
    if (!itemId) return '';
    const rows = await this.dataSource.query(
      'SELECT item_name FROM order_items WHERE id = $1 AND order_id = $2',
      [itemId, orderId],
    );
    return rows[0]?.item_name ?? '';
  }

  /** Menulis pesan sistem ke grup chat pelayanan agar seluruh anggota grup mengetahuinya. */
  async postChat(orderId: number, itemId: number | null | undefined, text: string): Promise<void> {
    const groupId = await this.groupIdFor(orderId, itemId);
    if (!groupId) return;
    await this.dataSource.query(
      `INSERT INTO chat_messages (chat_group_id, sender_id, message_type, message)
       VALUES ($1, NULL, 'SYSTEM_EVENT', $2)`,
      [groupId, text],
    );
    await this.dataSource.query(
      'UPDATE chat_groups SET last_message_text = $1, last_message_at = CURRENT_TIMESTAMP WHERE id = $2',
      [text, groupId],
    );
  }

  /**
   * Notifikasi dalam aplikasi + push. Grup chat misa disimpan pada notifikasi dan `itemId` dikirim
   * di data push, sehingga ketukan membuka misa yang dimaksud.
   */
  async notify(userIds: Array<number | null | undefined>, n: OrderNotification): Promise<void> {
    const recipients = Array.from(new Set(userIds.filter((id): id is number => !!id)));
    if (recipients.length === 0) return;
    const groupId = await this.groupIdFor(n.orderId, n.itemId);
    for (const userId of recipients) {
      await this.dataSource.query(
        `INSERT INTO notifications (user_id, order_id, chat_group_id, title, body, type, is_read)
         VALUES ($1, $2, $3, $4, $5, $6, false)`,
        [userId, n.orderId, groupId, n.title, n.body, n.type],
      );
    }
    try {
      const order = await this.dataSource.query('SELECT order_number FROM orders WHERE id = $1', [n.orderId]);
      await this.fcm.sendPushToUsers(recipients, {
        title: n.title,
        body: n.body,
        data: {
          type: n.type,
          orderId: String(n.orderId),
          itemId: n.itemId ? String(n.itemId) : '',
          orderNumber: order[0]?.order_number ?? '',
        },
      });
    } catch (err) {
      this.logger.error(`Gagal mengirim push ${n.type}: ${(err as Error).message}`);
    }
  }

  async rejectedRescheduleCount(orderId: number, itemId?: number | null): Promise<number> {
    const rows = await this.dataSource.query(
      `SELECT COUNT(*)::int AS total FROM order_reschedules
       WHERE order_id = $1 AND status = 'REJECTED' AND item_id IS NOT DISTINCT FROM $2::bigint`,
      [orderId, itemId || null],
    );
    return rows[0]?.total ?? 0;
  }

  /** 403 bila pengajuan ubah jam sudah ditutup (ditolak 2x); 400 bila masih ada pengajuan yang menunggu Umat. */
  async assertRescheduleOpen(orderId: number, itemId?: number | null): Promise<void> {
    if ((await this.rejectedRescheduleCount(orderId, itemId)) >= MAX_RESCHEDULE_REJECTIONS) {
      throw new ForbiddenException(
        `Pengajuan ubah jam sudah ditutup karena telah ditolak ${MAX_RESCHEDULE_REJECTIONS} kali. Jadwal tetap sesuai jadwal terakhir.`,
      );
    }
    const pending = await this.dataSource.query(
      `SELECT 1 FROM order_reschedules
       WHERE order_id = $1 AND status = 'PENDING_UMAT' AND item_id IS NOT DISTINCT FROM $2::bigint LIMIT 1`,
      [orderId, itemId || null],
    );
    if (pending.length > 0) {
      throw new BadRequestException('Masih ada pengajuan ubah jam yang menunggu tanggapan Umat.');
    }
  }

  /** Romo yang terakhir mengajukan ubah jam untuk pelayanan/misa ini. */
  async lastRescheduleProposer(orderId: number, itemId?: number | null): Promise<number | null> {
    const rows = await this.dataSource.query(
      `SELECT proposed_by FROM order_reschedules
       WHERE order_id = $1 AND item_id IS NOT DISTINCT FROM $2::bigint ORDER BY id DESC LIMIT 1`,
      [orderId, itemId || null],
    );
    return rows.length > 0 ? Number(rows[0].proposed_by) : null;
  }
}
