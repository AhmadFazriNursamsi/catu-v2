import { Injectable, BadRequestException, NotFoundException } from '@nestjs/common';
import { InjectDataSource } from '@nestjs/typeorm';
import { DataSource } from 'typeorm';
import { FcmService } from '../../fcm.service';

@Injectable()
export class OrderReviewsService {
  constructor(
    @InjectDataSource() private readonly dataSource: DataSource,
    private readonly fcmService: FcmService,
  ) {}

  async submitReview(
    orderIdParam: string,
    dto: {
      userId?: number;
      itemId?: number;
      rating: number;
      reviewNotes?: string;
    },
  ) {
    const orderId = parseInt(orderIdParam, 10) || 0;
    if (!orderId) {
      throw new BadRequestException('ID order tidak valid');
    }

    const rating = Math.round(Number(dto.rating));
    if (isNaN(rating) || rating < 1 || rating > 5) {
      throw new BadRequestException('Rating harus berupa angka antara 1 sampai 5');
    }

    const orderRows = await this.dataSource.query(
      `SELECT id, order_number, user_id, status, scheduled_date, accepted_romo_id FROM orders WHERE id = $1`,
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
        `SELECT id, status, scheduled_date, accepted_romo_id FROM order_items WHERE id = $1 AND order_id = $2`,
        [dto.itemId, orderId],
      );
      if (!itemRows || itemRows.length === 0) {
        throw new NotFoundException('Item pelayanan tidak ditemukan');
      }
      const item = itemRows[0];
      const itemSt = (item.status || '').toUpperCase();
      const orderSt = (order.status || '').toUpperCase();
      if (itemSt !== 'DONE' && itemSt !== 'CLOSE' && orderSt !== 'DONE' && orderSt !== 'CLOSE') {
        throw new BadRequestException('Ulasan hanya dapat diberikan setelah pelayanan selesai atau ditutup');
      }
      if (item.accepted_romo_id) {
        targetRomoId = Number(item.accepted_romo_id);
      }

      await this.dataSource.query(
        `UPDATE order_items SET rating = $1, review_notes = $2, reviewed_at = NOW() WHERE id = $3`,
        [rating, dto.reviewNotes?.trim() || null, dto.itemId],
      );
    } else {
      const orderSt = (order.status || '').toUpperCase();
      if (orderSt !== 'DONE' && orderSt !== 'CLOSE') {
        throw new BadRequestException('Ulasan hanya dapat diberikan setelah pelayanan selesai atau ditutup');
      }
    }

    await this.dataSource.query(
      `UPDATE orders SET rating = $1, review_notes = $2, reviewed_at = NOW() WHERE id = $3`,
      [rating, dto.reviewNotes?.trim() || null, orderId],
    );

    if (targetRomoId) {
      const notifTitle = 'Ulasan Pelayanan Diterima ⭐';
      const notifBody = `Umat telah memberikan ulasan (${rating}/5) untuk pelayanan #${order.order_number}`;
      const notifData = JSON.stringify({
        type: 'ORDER_REVIEW',
        orderId: order.id,
        orderNumber: order.order_number,
        rating,
      });

      await this.fcmService.sendPushToUsers([targetRomoId], {
        title: notifTitle,
        body: notifBody,
        data: {
          type: 'ORDER_REVIEW',
          orderId: order.id.toString(),
          orderNumber: order.order_number,
          rating: rating.toString(),
        },
      }).catch(() => {});

      await this.dataSource.query(
        `INSERT INTO notifications (user_id, title, body, data, is_read, created_at)
         VALUES ($1, $2, $3, $4, FALSE, NOW())`,
        [targetRomoId, notifTitle, notifBody, notifData],
      ).catch(() => {});
    }

    return {
      success: true,
      message: 'Ulasan berhasil disimpan. Terima kasih atas masukan Anda!',
      data: {
        orderId,
        itemId: dto.itemId || null,
        rating,
        reviewNotes: dto.reviewNotes?.trim() || '',
        reviewedAt: new Date().toISOString(),
      },
    };
  }
}
