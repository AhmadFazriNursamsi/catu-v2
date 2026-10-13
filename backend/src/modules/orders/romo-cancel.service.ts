import { BadRequestException, ConflictException, ForbiddenException, Injectable } from '@nestjs/common';
import { InjectDataSource } from '@nestjs/typeorm';
import { DataSource } from 'typeorm';
import { MAX_HANDOVER_REASON, OrderGuardsService } from '../order-rules/order-guards.service';
import { ONGOING_STATUSES } from '../order-rules/order-status-machine';
import { orderStatusFromItemsSql } from '../order-rules/order-status-derive';
import { OrderEventsService } from '../order-events/order-events.service';
import { OrdersService } from './orders.service';

/**
 * Pembatalan pelayanan oleh Romo limpahan (Romo yang menerima pelayanan lewat pelimpahan).
 * Romo limpahan tidak dapat mengajukan ubah jam; bila berhalangan, pelayanan (atau misanya) dibatalkan sepenuhnya:
 * status menjadi FAIL, alasan wajib dan tercatat di riwayat pengalihan (CANCELLED_BY_ROMO), Umat & pengurus diberi tahu.
 */
@Injectable()
export class RomoCancelService {
  constructor(
    @InjectDataSource() private readonly dataSource: DataSource,
    private readonly guards: OrderGuardsService,
    private readonly events: OrderEventsService,
    private readonly orders: OrdersService,
  ) {}

  async cancel(orderId: number, itemId: number | null | undefined, romoId: number, rawReason: string) {
    const reason = (rawReason ?? '').trim();
    if (!reason) throw new BadRequestException('Alasan pembatalan wajib diisi.');
    if (reason.length > MAX_HANDOVER_REASON) throw new BadRequestException(`Alasan maksimal ${MAX_HANDOVER_REASON} karakter.`);

    const t = await this.guards.target(orderId, itemId);
    if (t.acceptedRomoId !== Number(romoId)) throw new ForbiddenException('Hanya Romo yang bertugas yang dapat membatalkan pelayanan ini.');
    if (!(ONGOING_STATUSES as string[]).includes(t.status)) {
      throw new ConflictException(`Pelayanan hanya dapat dibatalkan selama masih berjalan (status saat ini ${t.status}).`);
    }
    if (!(await this.guards.isHandoverRecipient(orderId, itemId, romoId))) {
      throw new ForbiddenException('Batalkan Pelayanan hanya tersedia bagi Romo limpahan.');
    }

    const order = (await this.dataSource.query(`SELECT user_id, order_number FROM orders WHERE id = $1`, [orderId]))[0];
    await this.dataSource.transaction(async (m) => {
      if (itemId) {
        await m.query(`UPDATE order_items SET status = 'FAIL', reschedule_status = 'NONE' WHERE id = $1 AND order_id = $2`, [itemId, orderId]);
        await m.query(`UPDATE orders SET status = COALESCE(${orderStatusFromItemsSql('$1')}, status::text)::order_status_enum, updated_at = CURRENT_TIMESTAMP WHERE id = $1`, [orderId]);
      } else {
        await m.query(`UPDATE order_items SET status = 'FAIL', reschedule_status = 'NONE' WHERE order_id = $1 AND status NOT IN ('DONE', 'CLOSE')`, [orderId]);
        await m.query(`UPDATE orders SET status = 'FAIL', reschedule_status = 'NONE', updated_at = CURRENT_TIMESTAMP WHERE id = $1`, [orderId]);
      }
      await m.query(
        `INSERT INTO order_romo_handovers (order_id, item_id, previous_romo_id, new_romo_id, handover_type, reason, status, responded_at)
         VALUES ($1, $2, $3, NULL, 'CANCELLED_BY_ROMO', $4, 'ACCEPTED', CURRENT_TIMESTAMP)`,
        [orderId, itemId ?? null, romoId, reason],
      );
    });

    const romoName = (await this.dataSource.query(`SELECT full_name FROM user_profiles WHERE user_id = $1`, [romoId]))[0]?.full_name ?? 'Romo';
    const service = (await this.events.itemName(orderId, itemId)) || 'Pelayanan';
    await this.events.postChat(orderId, itemId, `Pemberitahuan: Romo ${romoName} membatalkan pelayanan ${service} dengan alasan: "${reason}".`);
    const pengurus = await this.orders.getPengurusForOrder(orderId);
    await this.events.notify([order?.user_id, ...pengurus.map((p: any) => p.id)], {
      orderId,
      itemId,
      type: 'ORDER_CANCELLED_BY_ROMO',
      title: `Pelayanan Dibatalkan: ${service}`,
      body: `Romo ${romoName} membatalkan pelayanan ${service} (${order?.order_number ?? ''}). Alasan: "${reason}". Silakan ajukan ulang bila masih membutuhkan pelayanan.`,
    });
    return { statusCode: 200, success: true, message: `Pelayanan ${service} telah dibatalkan.` };
  }
}
