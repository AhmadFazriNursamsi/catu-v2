import 'reflect-metadata';
import { DataSource } from 'typeorm';
import { DatabaseInitService } from '../../src/database/database-init.service';
import { EscalationSettingsService } from '../../src/modules/escalation/escalation-settings.service';
import { OrderNumberCounterSetup } from '../../src/modules/order-rules/order-rules.module';

/**
 * Tes integrasi memakai PostgreSQL sungguhan (bukan mock): isi TEST_DATABASE_URL dengan basis data KOSONG yang
 * sudah dimuat backend/init.sql dan namanya memuat "test". Tanpa variabel itu, seluruh tes integrasi dilewati.
 *   createdb catu_test && psql -d catu_test -f backend/init.sql
 *   TEST_DATABASE_URL=postgres://postgres:***@localhost:5432/catu_test npm run test:integration
 */
export const TEST_DATABASE_URL = process.env.TEST_DATABASE_URL;
export const describeDb: typeof describe = TEST_DATABASE_URL ? describe : describe.skip;

let shared: DataSource | null = null;

/** Koneksi bersama; skema dilengkapi persis seperti saat aplikasi start (DatabaseInitService dan penyiap tabel lain). */
export async function connect(): Promise<DataSource> {
  if (shared) return shared;
  const url = TEST_DATABASE_URL as string;
  if (!/test/i.test(new URL(url).pathname)) throw new Error('TEST_DATABASE_URL harus menunjuk basis data uji (nama memuat "test"), bukan basis data pengembangan.');
  const ds = new DataSource({ type: 'postgres', url });
  await ds.initialize();
  await new DatabaseInitService(ds).onModuleInit();
  await new EscalationSettingsService(ds).onModuleInit();
  await new OrderNumberCounterSetup(ds).onModuleInit();
  shared = ds;
  return ds;
}

export async function disconnect(): Promise<void> {
  if (shared) await shared.destroy();
  shared = null;
}

export interface FixtureUser {
  id: number;
  roleCode: string;
}

/** Data uji yang dibuat sebuah spesifikasi; semuanya dihapus oleh cleanup() agar basis data tetap bersih. */
export class Fixture {
  private users: number[] = [];
  private orders: number[] = [];
  private seq = 0;
  readonly tag = `it${Date.now().toString(36)}${Math.floor(Math.random() * 1e4)}`;

  constructor(readonly ds: DataSource) {}

  /** Dua paroki dari satu keuskupan dan dua kota berbeda dari data master. */
  async territory() {
    const paroki = await this.ds.query('SELECT id, keuskupan_id FROM paroki ORDER BY id LIMIT 2');
    const kota = await this.ds.query('SELECT id FROM kabupaten_kota ORDER BY id LIMIT 2');
    if (paroki.length < 2 || kota.length < 2) throw new Error('Data master paroki/kota belum dimuat (jalankan init.sql).');
    return { paroki1: Number(paroki[0].id), paroki2: Number(paroki[1].id), keuskupan: Number(paroki[0].keuskupan_id), kota1: Number(kota[0].id), kota2: Number(kota[1].id) };
  }

  async user(roleCode: string, profile: { parokiId?: number; kotaId?: number; keuskupanId?: number; status?: string } = {}): Promise<FixtureUser> {
    const phone = `628997${String(Date.now() % 1e6).padStart(6, '0')}${String(++this.seq).padStart(2, '0')}${Math.floor(Math.random() * 90 + 10)}`.slice(0, 18);
    const role = await this.ds.query('SELECT id FROM roles WHERE code = $1', [roleCode]);
    const u = await this.ds.query(
      `INSERT INTO auth_users (phone_number, password_hash, role_id, account_status) VALUES ($1, 'x', $2, $3::account_status_enum) RETURNING id`,
      [phone, role[0].id, profile.status ?? 'APPROVED'],
    );
    const id = Number(u[0].id);
    await this.ds.query(
      `INSERT INTO user_profiles (user_id, full_name, paroki_id, kabupaten_kota_id, keuskupan_id) VALUES ($1, $2, $3, $4, $5)`,
      [id, `Uji ${this.tag} ${roleCode} ${this.seq}`, profile.parokiId ?? null, profile.kotaId ?? null, profile.keuskupanId ?? null],
    );
    this.users.push(id);
    return { id, roleCode };
  }

  async order(over: { userId: number; parokiId?: number; kotaId?: number; status?: string; scheduledDate?: string; categoryId?: number } ): Promise<number> {
    const r = await this.ds.query(
      `INSERT INTO orders (order_number, user_id, service_category_id, urgency_level_id, paroki_id, kabupaten_kota_id, status, scheduled_date, scheduled_time, location_name, address_detail, notes)
       VALUES ($1, $2, $3, 1, $4, $5, $6::order_status_enum, COALESCE($7::date, CURRENT_DATE + 5), '18:00', 'RS Uji', 'Kamar 1', $8) RETURNING id`,
      [`IT-${this.tag}-${++this.seq}`, over.userId, over.categoryId ?? 1, over.parokiId ?? null, over.kotaId ?? null, over.status ?? 'PENDING', over.scheduledDate ?? null, `integration-test ${this.tag}`],
    );
    const id = Number(r[0].id);
    this.orders.push(id);
    return id;
  }

  async item(orderId: number, status = 'PENDING'): Promise<number> {
    const r = await this.ds.query(
      `INSERT INTO order_items (order_id, item_name, scheduled_date, scheduled_time_start, scheduled_time_end, location_name, status)
       VALUES ($1, 'Misa Uji', CURRENT_DATE + 5, '09:00', '10:00', 'Gereja', $2::order_status_enum) RETURNING id`,
      [orderId, status],
    );
    return Number(r[0].id);
  }

  async chatGroup(orderId: number): Promise<number> {
    const r = await this.ds.query(`INSERT INTO chat_groups (order_id, title) VALUES ($1, 'Grup uji') RETURNING id`, [orderId]);
    return Number(r[0].id);
  }

  async row(table: 'orders' | 'order_items', id: number): Promise<any> {
    return (await this.ds.query(`SELECT *, status::text AS status_text FROM ${table} WHERE id = $1`, [id]))[0];
  }

  /** Menghapus tanpa gagal bila tabel opsional (mis. activity_logs, dibuat saat aplikasi berjalan) belum ada. */
  private async del(sql: string, id: number): Promise<void> {
    try {
      await this.ds.query(sql, [id]);
    } catch (err) {
      if ((err as { code?: string }).code !== '42P01') throw err;
    }
  }

  async cleanup(): Promise<void> {
    for (const oid of this.orders) {
      for (const sql of [
        'DELETE FROM chat_message_reads WHERE message_id IN (SELECT m.id FROM chat_messages m JOIN chat_groups g ON g.id = m.chat_group_id WHERE g.order_id = $1)',
        'DELETE FROM chat_messages WHERE chat_group_id IN (SELECT id FROM chat_groups WHERE order_id = $1)',
        'DELETE FROM chat_group_members WHERE chat_group_id IN (SELECT id FROM chat_groups WHERE order_id = $1)',
        'DELETE FROM notifications WHERE order_id = $1',
        'DELETE FROM chat_groups WHERE order_id = $1',
        'DELETE FROM order_reschedules WHERE order_id = $1',
        'DELETE FROM order_romo_handovers WHERE order_id = $1',
        'DELETE FROM order_monitors WHERE order_id = $1',
        'DELETE FROM order_assignments WHERE order_id = $1',
        'DELETE FROM order_items WHERE order_id = $1',
        'DELETE FROM orders WHERE id = $1',
      ]) {
        await this.del(sql, oid);
      }
    }
    for (const uid of this.users) {
      for (const sql of [
        'DELETE FROM chat_group_members WHERE user_id = $1',
        'DELETE FROM notifications WHERE user_id = $1',
        'DELETE FROM activity_logs WHERE user_id = $1',
        'DELETE FROM user_profiles WHERE user_id = $1',
        'DELETE FROM auth_users WHERE id = $1',
      ]) {
        await this.del(sql, uid);
      }
    }
    this.orders = [];
    this.users = [];
  }
}
