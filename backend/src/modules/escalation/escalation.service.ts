import { ForbiddenException, Injectable, Logger, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { InjectDataSource } from '@nestjs/typeorm';
import { DataSource } from 'typeorm';
import { OrderEventsService } from '../order-events/order-events.service';
import { EscalationSettingsService } from './escalation-settings.service';
import { isOpenForOrdo, opensAt } from './escalation-rules';
import { orderKeuskupanSql } from '../order-rules/lintas-paroki';

const TICK_MS = 15_000;
/** Pelayanan lebih tua dari ini tidak lagi dieskalasi (mencegah banjir notifikasi untuk data lama). */
const ESCALATION_WINDOW = `INTERVAL '2 days'`;

/** Pelayanan yang masih belum diterima Romo mana pun (order tanpa item, atau ada item PENDING tanpa Romo). */
const UNACCEPTED = `(
  (NOT EXISTS (SELECT 1 FROM order_items i WHERE i.order_id = o.id) AND o.status = 'PENDING' AND o.accepted_romo_id IS NULL)
  OR EXISTS (SELECT 1 FROM order_items i WHERE i.order_id = o.id AND i.status = 'PENDING' AND i.accepted_romo_id IS NULL)
)`;

interface DueOrder {
  id: number;
  order_number: string;
  user_id: number | null;
  category_name: string;
  kabupaten_kota_id: number | null;
  keuskupan_id: number | null;
  lingkungan_id: number | null;
}

/**
 * Eskalasi pelayanan berjenjang: Romo Paroki langsung; Romo Ordo setelah N menit; Koordinator setelah M menit
 * (untuk mencarikan Romo). Koordinator tidak lagi diberi tahu soal pelayanan sebelum eskalasi.
 */
@Injectable()
export class EscalationService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(EscalationService.name);
  private timer?: NodeJS.Timeout;
  private running = false;

  constructor(
    @InjectDataSource() private readonly dataSource: DataSource,
    private readonly settings: EscalationSettingsService,
    private readonly events: OrderEventsService,
  ) {}

  onModuleInit() {
    if (process.env.NODE_ENV === 'test') return;
    this.timer = setInterval(() => void this.tick(), TICK_MS);
    this.timer.unref();
  }

  onModuleDestroy() {
    if (this.timer) clearInterval(this.timer);
  }

  /** Romo Ordo hanya boleh menerima pelayanan setelah terbuka (Romo Paroki dan admin tidak dibatasi). */
  async assertCanAccept(user: { sub: number; roleCode: string }, orderId: number, status: string): Promise<void> {
    if (user.roleCode !== 'ROMO_ORDO' || !['ACCEPTED', 'CONFIRMED'].includes(status)) return;
    const rows = await this.dataSource.query(
      `SELECT o.created_at, o.accepted_romo_id, COALESCE(o.paroki_id, p.paroki_id) AS paroki_id, o.lintas_paroki
       FROM orders o LEFT JOIN user_profiles p ON p.user_id = o.user_id WHERE o.id = $1`,
      [orderId],
    );
    if (rows.length === 0 || Number(rows[0].accepted_romo_id) === Number(user.sub)) return;
    const { ordoAfterMinutes } = await this.settings.get();
    // Pelayanan lintas paroki tidak punya Romo Paroki yang perlu ditunggu: langsung terbuka untuk Romo Ordo tujuan.
    const order = { createdAt: new Date(rows[0].created_at), hasParoki: !!rows[0].paroki_id && !rows[0].lintas_paroki };
    if (isOpenForOrdo(order, ordoAfterMinutes, new Date())) return;
    const time = opensAt(order.createdAt, ordoAfterMinutes)
      .toLocaleTimeString('id-ID', { timeZone: 'Asia/Jakarta', hour: '2-digit', minute: '2-digit' })
      .replace('.', ':');
    throw new ForbiddenException(`Pelayanan ini masih menunggu Romo Paroki. Baru dapat diterima Romo Ordo mulai pukul ${time} WIB.`);
  }

  async tick(): Promise<void> {
    if (this.running) return;
    this.running = true;
    try {
      const { ordoAfterMinutes, koordinatorAfterMinutes } = await this.settings.get();
      for (const o of await this.claimDue('ordo_notified_at', ordoAfterMinutes, true)) await this.escalateToOrdo(o);
      for (const o of await this.claimDue('koordinator_notified_at', koordinatorAfterMinutes, false)) await this.escalateToKoordinator(o);
    } catch (err) {
      this.logger.error(`Eskalasi gagal: ${(err as Error).message}`);
    } finally {
      this.running = false;
    }
  }

  /** Menandai (atomik) pelayanan yang sudah jatuh tempo agar setiap eskalasi hanya diproses sekali. */
  private async claimDue(column: 'ordo_notified_at' | 'koordinator_notified_at', minutes: number, openWithoutParoki: boolean): Promise<DueOrder[]> {
    const noParoki = `COALESCE(o.paroki_id, (SELECT paroki_id FROM user_profiles WHERE user_id = o.user_id)) IS NULL`;
    const result = await this.dataSource.query(
      `WITH due AS (
         SELECT o.id FROM orders o
         WHERE o.${column} IS NULL
           AND o.created_at > NOW() - ${ESCALATION_WINDOW}
           AND (o.created_at <= NOW() - ($1 * INTERVAL '1 minute') ${openWithoutParoki ? `OR ${noParoki} OR o.lintas_paroki` : ''})
           AND ${UNACCEPTED}
         FOR UPDATE SKIP LOCKED
       )
       UPDATE orders o SET ${column} = NOW() FROM due WHERE o.id = due.id
       RETURNING o.id, o.order_number, o.user_id,
         (SELECT name FROM service_categories WHERE id = o.service_category_id) AS category_name,
         COALESCE(o.kabupaten_kota_id, (SELECT kabupaten_kota_id FROM user_profiles WHERE user_id = o.user_id)) AS kabupaten_kota_id,
         COALESCE(o.keuskupan_id, (SELECT keuskupan_id FROM user_profiles WHERE user_id = o.user_id)) AS keuskupan_id,
         COALESCE(o.lingkungan_id, (SELECT lingkungan_id FROM user_profiles WHERE user_id = o.user_id)) AS lingkungan_id`,
      [minutes],
    );
    // TypeORM (pg) mengembalikan [baris, jumlah] untuk UPDATE ... RETURNING
    return Array.isArray(result[0]) ? result[0] : result;
  }

  private async escalateToOrdo(o: DueOrder) {
    try {
      const romo = o.kabupaten_kota_id
        ? await this.dataSource.query(
            `SELECT u.id FROM auth_users u JOIN user_profiles p ON u.id = p.user_id JOIN roles r ON u.role_id = r.id
             WHERE r.code = 'ROMO_ORDO' AND u.account_status = 'APPROVED' AND p.kabupaten_kota_id = $1`,
            [o.kabupaten_kota_id],
          )
        : [];
      await this.postToGroups(o.id, 'Belum ada Romo Paroki yang menerima pelayanan ini. Kini terbuka untuk Romo Ordo.');
      await this.events.notifyPerItem(romo.map((r: any) => r.id).filter((id: number) => id !== o.user_id), o.id, (item) => ({
        type: 'NEW_ORDER_ROMO',
        title: `Permintaan Pelayanan ${item?.name || o.category_name}`,
        body: `Pelayanan ${item ? `${o.category_name} - ${item.name}` : o.category_name} (${o.order_number}) di kota Anda belum diterima Romo Paroki dan kini terbuka untuk Anda terima.`,
      }), true);
    } catch (err) {
      this.logger.error(`Eskalasi ke Romo Ordo gagal untuk order ${o.id}: ${(err as Error).message}`);
    }
  }

  private async escalateToKoordinator(o: DueOrder) {
    try {
      // Keuskupan pemohon, ditambah keuskupan tujuan bila pelayanan lintas paroki.
      const keuskupan = (await this.dataSource.query(orderKeuskupanSql('$1'), [o.id])).map((r: any) => Number(r.keuskupan_id)).filter(Boolean);
      const koordinator = await this.dataSource.query(
        `SELECT u.id FROM auth_users u JOIN user_profiles p ON u.id = p.user_id JOIN roles r ON u.role_id = r.id
         WHERE u.account_status = 'APPROVED'
           AND (r.code LIKE '%KOORDINATOR%' OR LOWER(COALESCE(p.pengurus_position, '')) LIKE '%koordinator%')
           AND p.keuskupan_id = ANY($1::int[])`,
        [keuskupan],
      );
      const ids: number[] = koordinator.map((k: any) => Number(k.id));
      for (const id of ids) {
        await this.dataSource.query(
          `INSERT INTO chat_group_members (chat_group_id, user_id, role_in_group)
           SELECT g.id, $2, 'KOORDINATOR' FROM chat_groups g WHERE g.order_id = $1
           ON CONFLICT (chat_group_id, user_id) DO UPDATE SET role_in_group = 'KOORDINATOR'`,
          [o.id, id],
        );
      }
      await this.postToGroups(o.id, 'Belum ada Romo yang menerima pelayanan ini. Koordinator membantu mencarikan Romo.');
      await this.events.notifyPerItem(ids, o.id, (item) => ({
        type: 'NEW_ORDER_KOORDINATOR',
        title: `Perlu Romo: ${item?.name || o.category_name}`,
        body: `Pelayanan ${item ? `${o.category_name} - ${item.name}` : o.category_name} (${o.order_number}) belum diterima Romo Paroki maupun Romo Ordo. Mohon bantu mencarikan Romo.`,
      }), true);
    } catch (err) {
      this.logger.error(`Eskalasi ke Koordinator gagal untuk order ${o.id}: ${(err as Error).message}`);
    }
  }

  private async postToGroups(orderId: number, text: string) {
    await this.dataSource.query(
      `INSERT INTO chat_messages (chat_group_id, sender_id, message_type, message)
       SELECT id, NULL, 'SYSTEM_EVENT', $2 FROM chat_groups WHERE order_id = $1`,
      [orderId, text],
    );
    await this.dataSource.query(
      'UPDATE chat_groups SET last_message_text = $2, last_message_at = CURRENT_TIMESTAMP WHERE order_id = $1',
      [orderId, text],
    );
  }
}
