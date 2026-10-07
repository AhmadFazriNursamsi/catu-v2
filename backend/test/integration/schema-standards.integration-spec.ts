import { DataSource } from 'typeorm';
import { runMigrations } from '../../src/database/migrate';
import { Fixture, TEST_DATABASE_URL, connect, describeDb, disconnect } from './db-fixture';

/** Standar skema untuk produksi: dijaga pada basis data yang dibangun murni dari migrasi. */
describeDb('Standar skema basis data (migrasi dari nol)', () => {
  let ds: DataSource;
  let fx: Fixture;

  beforeAll(async () => {
    ds = await connect();
    fx = new Fixture(ds);
  });
  afterAll(async () => {
    try {
      await fx.cleanup();
    } finally {
      await disconnect();
    }
  });

  const rows = (sql: string, params: unknown[] = []) => ds.query(sql, params);

  it('migrasi dapat dijalankan ulang tanpa galat dan tanpa menambah catatan migrasi', async () => {
    const before = Number((await rows('SELECT count(*)::int AS n FROM drizzle.__drizzle_migrations'))[0].n);
    await runMigrations({ connectionString: TEST_DATABASE_URL, max: 1 });
    expect(Number((await rows('SELECT count(*)::int AS n FROM drizzle.__drizzle_migrations'))[0].n)).toBe(before);
  });

  it('setiap kolom relasi (FK) punya indeks pendukung', async () => {
    const missing = await rows(`
      SELECT c.conrelid::regclass::text AS tabel, a.attname AS kolom
      FROM pg_constraint c JOIN pg_attribute a ON a.attrelid = c.conrelid AND a.attnum = c.conkey[1]
      WHERE c.contype = 'f' AND c.connamespace = 'public'::regnamespace AND array_length(c.conkey, 1) = 1
        AND NOT EXISTS (SELECT 1 FROM pg_index i WHERE i.indrelid = c.conrelid AND i.indkey[0] = c.conkey[1])`);
    expect(missing).toEqual([]);
  });

  it('tidak ada relasi (FK) ganda dan tidak ada nama gaya lama *_fk', async () => {
    const dupes = await rows(`SELECT conrelid::regclass::text AS tabel FROM pg_constraint WHERE contype = 'f' AND connamespace = 'public'::regnamespace GROUP BY conrelid, conkey, confrelid, confkey HAVING count(*) > 1`);
    const old = await rows(`SELECT conname FROM pg_constraint WHERE contype = 'f' AND connamespace = 'public'::regnamespace AND conname LIKE '%\\_fk'`);
    expect({ dupes, old }).toEqual({ dupes: [], old: [] });
  });

  it('semua kolom waktu memakai zona waktu, tidak ada enum mati, tidak ada kolom *_id yang yatim tanpa relasi penting', async () => {
    expect(await rows(`SELECT table_name, column_name FROM information_schema.columns WHERE table_schema = 'public' AND data_type = 'timestamp without time zone'`)).toEqual([]);
    expect(await rows(`SELECT typname FROM pg_type WHERE typname IN ('romo_position_enum', 'pengurus_position_enum', 'notification_type_enum')`)).toEqual([]);
    const fks = (await rows(`SELECT conname FROM pg_constraint WHERE contype = 'f' AND connamespace = 'public'::regnamespace`)).map((r: any) => r.conname);
    for (const name of ['orders_accepted_romo_id_fkey', 'order_items_accepted_romo_id_fkey', 'orders_reschedule_proposed_by_fkey', 'order_items_reschedule_proposed_by_fkey', 'user_profiles_ordo_id_fkey', 'chat_group_members_last_read_message_id_fkey']) {
      expect(fks).toContain(name);
    }
  });

  it('data referensi tersedia dan lengkap', async () => {
    expect((await rows('SELECT code FROM roles ORDER BY code')).map((r: any) => r.code)).toEqual(
      ['ADMIN', 'KOORDINATOR_KEUSKUPAN', 'PENGURUS_LINGKUNGAN', 'ROMO_ORDO', 'ROMO_PAROKI', 'SUPERADMIN', 'UMAT', 'UMAT_PENDATANG'],
    );
    expect((await rows('SELECT id FROM service_categories ORDER BY id')).map((r: any) => Number(r.id))).toEqual([1, 2]);
    expect(Number((await rows('SELECT count(*)::int AS n FROM urgency_levels'))[0].n)).toBe(3);
    expect(Number((await rows('SELECT count(*)::int AS n FROM master_positions'))[0].n)).toBeGreaterThanOrEqual(8);
  });

  it('tidak ada akun yang dibuat otomatis oleh migrasi atau aplikasi (akun admin pertama dibuat lewat skrip)', async () => {
    const fixtureUsers = Number((await rows(`SELECT count(*)::int AS n FROM auth_users WHERE phone_number IN ('6288888888888', '6289999999999')`))[0].n);
    expect(fixtureUsers).toBe(0);
  });

  describe('aturan data ditegakkan oleh basis data', () => {
    let orderId: number;
    let itemId: number;
    beforeAll(async () => {
      const u = await fx.user('UMAT');
      orderId = await fx.order({ userId: u.id, categoryId: 2 });
      itemId = await fx.item(orderId, 'PENDING');
    });

    const rejects = async (sql: string, params: unknown[], fragment: RegExp) => {
      await expect(ds.query(sql, params)).rejects.toThrow(fragment);
    };

    it('status di luar standar ditolak', async () => {
      await rejects(`UPDATE order_items SET status = 'ACCEPTED' WHERE id = $1`, [itemId], /chk_order_items_status/);
      await rejects(`UPDATE order_items SET status = NULL WHERE id = $1`, [itemId], /not-null|null value/i);
      await rejects(`UPDATE orders SET status = 'COMPLETED' WHERE id = $1`, [orderId], /chk_orders_status/);
      await rejects(`UPDATE orders SET reschedule_status = 'BOGUS' WHERE id = $1`, [orderId], /chk_orders_reschedule_status/);
      await rejects(`UPDATE orders SET handover_status = 'BOGUS' WHERE id = $1`, [orderId], /chk_orders_handover_status/);
    });

    it('rating di luar 1-5, jam selesai <= jam mulai, tipe notifikasi dan nomor HP tidak wajar ditolak', async () => {
      await rejects(`UPDATE orders SET rating = 6 WHERE id = $1`, [orderId], /chk_orders_rating/);
      await rejects(`UPDATE order_items SET rating = 0 WHERE id = $1`, [itemId], /chk_order_items_rating/);
      await rejects(`UPDATE order_items SET scheduled_time_end = scheduled_time_start WHERE id = $1`, [itemId], /chk_order_items_time_range/);
      await rejects(`INSERT INTO notifications (user_id, title, body, type) SELECT user_id, 't', 'b', 'tipe kecil' FROM orders WHERE id = $1`, [orderId], /chk_notifications_type_format/);
      await rejects(`INSERT INTO auth_users (phone_number, password_hash, role_id) VALUES ('08123', 'x', 1)`, [], /chk_auth_users_phone_format/);
    });

    it('relasi baru: Romo yang tidak ada ditolak', async () => {
      await rejects(`UPDATE orders SET accepted_romo_id = 2147483000 WHERE id = $1`, [orderId], /orders_accepted_romo_id_fkey/);
      await rejects(`UPDATE order_items SET accepted_romo_id = 2147483000 WHERE id = $1`, [itemId], /order_items_accepted_romo_id_fkey/);
    });

    it('satu grup chat per misa dan per pelayanan tanpa misa', async () => {
      await ds.query(`INSERT INTO chat_groups (order_id, order_item_id, title) VALUES ($1, $2, 'g1')`, [orderId, itemId]);
      await rejects(`INSERT INTO chat_groups (order_id, order_item_id, title) VALUES ($1, $2, 'g2')`, [orderId, itemId], /uq_chat_groups_order_item/);
      const plain = await fx.order({ userId: (await fx.user('UMAT')).id });
      await ds.query(`INSERT INTO chat_groups (order_id, title) VALUES ($1, 'g1')`, [plain]);
      await rejects(`INSERT INTO chat_groups (order_id, title) VALUES ($1, 'g2')`, [plain], /uq_chat_groups_order_item/);
    });

    it('updated_at diperbarui otomatis oleh basis data bila baris berubah, dan tidak bila tidak ada perubahan', async () => {
      // Trigger menimpa nilai manual: updated_at tidak dapat dimundurkan atau dipalsukan dari aplikasi.
      await ds.query(`UPDATE orders SET updated_at = '2000-01-01', notes = 'awal' WHERE id = $1`, [orderId]);
      const before = (await ds.query('SELECT updated_at FROM orders WHERE id = $1', [orderId]))[0].updated_at as Date;
      expect(before.getFullYear()).toBeGreaterThan(2020);
      await ds.query('SELECT pg_sleep(0.05)');
      await ds.query(`UPDATE orders SET notes = notes WHERE id = $1`, [orderId]); // tanpa perubahan nilai
      expect(((await ds.query('SELECT updated_at FROM orders WHERE id = $1', [orderId]))[0].updated_at as Date).getTime()).toBe(before.getTime());
      await ds.query(`UPDATE orders SET notes = 'berubah' WHERE id = $1`, [orderId]);
      expect(((await ds.query('SELECT updated_at FROM orders WHERE id = $1', [orderId]))[0].updated_at as Date).getTime()).toBeGreaterThan(before.getTime());
      await ds.query(`UPDATE order_items SET notes = 'x' WHERE id = $1`, [itemId]);
      const item = (await ds.query('SELECT created_at, updated_at FROM order_items WHERE id = $1', [itemId]))[0];
      expect(new Date(item.updated_at).getTime()).toBeGreaterThanOrEqual(new Date(item.created_at).getTime());
    });
  });
});
