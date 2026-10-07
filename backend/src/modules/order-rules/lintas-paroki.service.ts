import { Injectable } from '@nestjs/common';
import { InjectDataSource } from '@nestjs/typeorm';
import { DataSource } from 'typeorm';
import { OrderEventsService } from '../order-events/order-events.service';
import { isLintasParoki, orderKeuskupanSql } from './lintas-paroki';

/**
 * Pelayanan lintas paroki (paroki penerima berbeda dari paroki pemohon), segera setelah dibuat:
 * - hanya Romo Ordo tujuan (kota pelayanan) yang diberi tahu dan berwenang, tanpa parameter jeda;
 * - Romo Paroki tidak berwenang; pengurus lingkungan pemohon tetap memantau dan masuk grup chat (alur biasa);
 * - Koordinator keuskupan pemohon dan keuskupan tujuan masuk grup chat dan diberi tahu.
 */
@Injectable()
export class LintasParokiService {
  constructor(
    @InjectDataSource() private readonly dataSource: DataSource,
    private readonly events: OrderEventsService,
  ) {}

  /** Mengembalikan true bila pelayanan memang lintas paroki dan sudah diteruskan ke Romo Ordo tujuan. */
  async afterCreate(orderId: number): Promise<boolean> {
    const rows = await this.dataSource.query(
      `SELECT o.order_number, o.user_id, o.paroki_id, o.kabupaten_kota_id, pem.paroki_id AS pemohon_paroki, sc.name AS category_name
       FROM orders o LEFT JOIN user_profiles pem ON pem.user_id = o.user_id JOIN service_categories sc ON sc.id = o.service_category_id
       WHERE o.id = $1`,
      [orderId],
    );
    if (rows.length === 0 || !isLintasParoki(rows[0].paroki_id, rows[0].pemohon_paroki)) return false;
    const o = rows[0];
    // Tanda lintas paroki sekaligus menandai Romo Ordo sudah dibuka (tidak menunggu jeda eskalasi).
    await this.dataSource.query('UPDATE orders SET lintas_paroki = TRUE, ordo_notified_at = NOW() WHERE id = $1', [orderId]);

    const keuskupan = (await this.dataSource.query(orderKeuskupanSql('$1'), [orderId])).map((r: any) => Number(r.keuskupan_id)).filter(Boolean);
    const [ordo, koordinator] = await Promise.all([
      o.kabupaten_kota_id
        ? this.dataSource.query(
            `SELECT u.id FROM auth_users u JOIN user_profiles p ON p.user_id = u.id JOIN roles r ON r.id = u.role_id
             WHERE r.code = 'ROMO_ORDO' AND u.account_status = 'APPROVED' AND p.kabupaten_kota_id = $1`,
            [o.kabupaten_kota_id],
          )
        : [],
      keuskupan.length === 0
        ? []
        : this.dataSource.query(
            `SELECT u.id FROM auth_users u JOIN user_profiles p ON p.user_id = u.id JOIN roles r ON r.id = u.role_id
             WHERE u.account_status = 'APPROVED' AND (r.code LIKE '%KOORDINATOR%' OR LOWER(COALESCE(p.pengurus_position, '')) LIKE '%koordinator%')
               AND p.keuskupan_id = ANY($1::int[])`,
            [keuskupan],
          ),
    ]);
    const koordinatorIds: number[] = koordinator.map((k: any) => Number(k.id));
    for (const id of koordinatorIds) {
      await this.dataSource.query(
        `INSERT INTO chat_group_members (chat_group_id, user_id, role_in_group)
         SELECT g.id, $2, 'KOORDINATOR' FROM chat_groups g WHERE g.order_id = $1
         ON CONFLICT (chat_group_id, user_id) DO UPDATE SET role_in_group = 'KOORDINATOR'`,
        [orderId, id],
      );
    }
    const text = 'Pelayanan ini untuk paroki di luar paroki pemohon, sehingga diteruskan langsung ke Romo Ordo tujuan. Romo Paroki tidak berwenang atas pelayanan ini.';
    await this.dataSource.query(
      `INSERT INTO chat_messages (chat_group_id, sender_id, message_type, message) SELECT id, NULL, 'SYSTEM_EVENT', $2 FROM chat_groups WHERE order_id = $1`,
      [orderId, text],
    );
    await this.dataSource.query('UPDATE chat_groups SET last_message_text = $2, last_message_at = CURRENT_TIMESTAMP WHERE order_id = $1', [orderId, text]);

    const creator = Number(o.user_id);
    // Satu notifikasi per misa (menaut ke grup misanya) untuk Romo Ordo tujuan dan Koordinator, seperti Romo Paroki pada pelayanan satu paroki.
    const ordoIds = ordo.map((r: any) => Number(r.id)).filter((id: number) => id !== creator);
    await this.events.notifyPerItem(ordoIds, orderId, (item) => ({
      type: 'NEW_ORDER_ROMO',
      title: `Permintaan Pelayanan ${item?.name || o.category_name}`,
      body: `Pelayanan ${item ? `${o.category_name} - ${item.name}` : o.category_name} (${o.order_number}) untuk paroki di kota Anda dari umat lintas paroki. Romo Ordo tujuan dapat langsung menerimanya.`,
    }));
    await this.events.notifyPerItem(koordinatorIds.filter((id) => id !== creator), orderId, (item) => ({
      type: 'NEW_ORDER_KOORDINATOR',
      title: `Pemantauan Pelayanan Lintas Paroki: ${item?.name || o.category_name}`,
      body: `Pelayanan ${item ? `${o.category_name} - ${item.name}` : o.category_name} (${o.order_number}) lintas paroki diteruskan ke Romo Ordo tujuan. Anda masuk grup chat untuk berdiskusi dengan pengurus dan pemohon.`,
    }));
    return true;
  }
}
