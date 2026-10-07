import { Injectable, BadRequestException, ConflictException, Logger, NotFoundException } from '@nestjs/common';
import { InjectDataSource } from '@nestjs/typeorm';
import { DataSource } from 'typeorm';
import { FcmService } from '../../fcm.service';
import { validateReview } from '../order-rules/order-input-rules';

@Injectable()
export class OrderReviewsService {
  private readonly logger = new Logger(OrderReviewsService.name);

  constructor(
    @InjectDataSource() private readonly dataSource: DataSource,
    private readonly fcmService: FcmService,
  ) {}

  async submitReview(
    orderIdParam: string,
    dto: {
      userId?: number;
      itemId?: number;
      rating?: number;
      reviewNotes: string;
    },
  ) {
    const orderId = parseInt(orderIdParam, 10) || 0;
    if (!orderId) {
      throw new BadRequestException('ID order tidak valid');
    }

    const invalid = validateReview(dto);
    if (invalid) throw new BadRequestException(invalid);
    const reviewNotes = dto.reviewNotes.trim();

    const rating = dto.rating != null ? Math.round(Number(dto.rating)) : null;

    const orderRows = await this.dataSource.query(
      `SELECT id, order_number, user_id, status, scheduled_date, accepted_romo_id, reviewed_at FROM orders WHERE id = $1`,
      [orderId],
    );
    if (!orderRows || orderRows.length === 0) {
      throw new NotFoundException('Order tidak ditemukan');
    }

    const order = orderRows[0];
    if (dto.userId && Number(order.user_id) !== Number(dto.userId)) {
      throw new BadRequestException('Hanya pemohon yang dapat memberikan ulasan pelayanan');
    }

    let targetRomoId = order.accepted_romo_id ? Number(order.accepted_romo_id) : null;

    if (dto.itemId) {
      const itemRows = await this.dataSource.query(
        `SELECT id, status, scheduled_date, accepted_romo_id, reviewed_at FROM order_items WHERE id = $1 AND order_id = $2`,
        [dto.itemId, orderId],
      );
      if (!itemRows || itemRows.length === 0) {
        throw new NotFoundException('Item pelayanan tidak ditemukan');
      }
      const item = itemRows[0];
      const itemSt = (item.status || '').toUpperCase();
      // Ulasan sebuah misa hanya setelah misa itu sendiri selesai/ditutup; status induk tidak cukup.
      if (itemSt !== 'DONE' && itemSt !== 'CLOSE') {
        throw new BadRequestException('Ulasan hanya dapat diberikan setelah pelayanan selesai atau ditutup');
      }
      if (item.reviewed_at) throw new ConflictException('Ulasan untuk pelayanan ini sudah pernah diberikan.');
      if (item.accepted_romo_id) {
        targetRomoId = Number(item.accepted_romo_id);
      }

      await this.dataSource.query(
        `UPDATE order_items SET rating = $1, review_notes = $2, reviewed_at = NOW() WHERE id = $3`,
        [rating, reviewNotes, dto.itemId],
      );
    } else {
      const orderSt = (order.status || '').toUpperCase();
      if (orderSt !== 'DONE' && orderSt !== 'CLOSE') {
        throw new BadRequestException('Ulasan hanya dapat diberikan setelah pelayanan selesai atau ditutup');
      }
      if (order.reviewed_at) throw new ConflictException('Ulasan untuk pelayanan ini sudah pernah diberikan.');
    }

    await this.dataSource.query(
      `UPDATE orders SET rating = $1, review_notes = $2, reviewed_at = NOW() WHERE id = $3`,
      [rating, reviewNotes, orderId],
    );

    if (targetRomoId) {
      const notifTitle = 'Ulasan Pelayanan Diterima';
      const notifBody = `Umat telah memberikan ulasan untuk pelayanan #${order.order_number}`;

      await this.fcmService.sendPushToUsers([targetRomoId], {
        title: notifTitle,
        body: notifBody,
        data: {
          type: 'ORDER_REVIEW',
          orderId: order.id.toString(),
          orderNumber: order.order_number,
        },
      }).catch(() => {});

      // Kolom type dan order_id wajib agar notifikasi tersimpan dan ketukannya membuka pelayanan yang tepat.
      await this.dataSource.query(
        `INSERT INTO notifications (user_id, order_id, title, body, type, is_read, created_at)
         VALUES ($1, $2, $3, $4, 'ORDER_REVIEW', FALSE, NOW())`,
        [targetRomoId, order.id, notifTitle, notifBody],
      ).catch((err) => this.logger.error(`Gagal menyimpan notifikasi ulasan: ${err.message}`));
    }

    return {
      success: true,
      message: 'Ulasan berhasil dikirim. Terima kasih atas masukan Anda!',
      data: {
        orderId,
        itemId: dto.itemId || null,
        reviewNotes,
        reviewedAt: new Date().toISOString(),
      },
    };
  }
}
