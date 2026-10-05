import { BadRequestException, ConflictException, ForbiddenException } from '@nestjs/common';
import { DataSource } from 'typeorm';
import { AcceptanceClaimService } from '../../src/modules/order-rules/acceptance-claim.service';
import { OrderGuardsService } from '../../src/modules/order-rules/order-guards.service';
import { generateOrderNumber } from '../../src/modules/orders/order-number';
import { Fixture, connect, describeDb, disconnect } from './db-fixture';

describeDb('Aturan pelayanan (PostgreSQL sungguhan)', () => {
  let ds: DataSource;
  let fx: Fixture;
  let claims: AcceptanceClaimService;
  let guards: OrderGuardsService;
  let t: Awaited<ReturnType<Fixture['territory']>>;

  beforeAll(async () => {
    ds = await connect();
    fx = new Fixture(ds);
    claims = new AcceptanceClaimService(ds);
    guards = new OrderGuardsService(ds);
    t = await fx.territory();
  });
  afterAll(async () => {
    try {
      await fx.cleanup();
    } finally {
      await disconnect();
    }
  });

  describe('AcceptanceClaimService', () => {
    it('dua Romo menerima bersamaan: tepat satu menang, yang lain mendapat 409 (15 percobaan)', async () => {
      const umat = await fx.user('UMAT', { parokiId: t.paroki1 });
      const a = await fx.user('ROMO_PAROKI', { parokiId: t.paroki1 });
      const b = await fx.user('ROMO_PAROKI', { parokiId: t.paroki1 });
      for (let i = 0; i < 15; i++) {
        const orderId = await fx.order({ userId: umat.id, parokiId: t.paroki1 });
        const results = await Promise.allSettled([
          claims.claim({ orderId, romoId: a.id, enforceTerritory: true }),
          claims.claim({ orderId, romoId: b.id, enforceTerritory: true }),
        ]);
        const won = results.filter((r) => r.status === 'fulfilled');
        const lost = results.filter((r) => r.status === 'rejected') as PromiseRejectedResult[];
        expect(won).toHaveLength(1);
        expect(lost).toHaveLength(1);
        expect(lost[0].reason).toBeInstanceOf(ConflictException);
        const winner = results[0].status === 'fulfilled' ? a.id : b.id;
        expect(Number((await fx.row('orders', orderId)).accepted_romo_id)).toBe(winner);
      }
    });

    it('Romo Paroki hanya untuk parokinya; Romo Ordo hanya untuk kotanya; Admin dikecualikan', async () => {
      const umat = await fx.user('UMAT', { parokiId: t.paroki1, kotaId: t.kota1 });
      const romoSama = await fx.user('ROMO_PAROKI', { parokiId: t.paroki1 });
      const romoLain = await fx.user('ROMO_PAROKI', { parokiId: t.paroki2 });
      const ordoSama = await fx.user('ROMO_ORDO', { kotaId: t.kota1 });
      const ordoLain = await fx.user('ROMO_ORDO', { kotaId: t.kota2 });
      const order = () => fx.order({ userId: umat.id, parokiId: t.paroki1, kotaId: t.kota1 });

      const o1 = await order();
      await expect(claims.claim({ orderId: o1, romoId: romoLain.id, enforceTerritory: true })).rejects.toBeInstanceOf(ForbiddenException);
      expect((await fx.row('orders', o1)).accepted_romo_id).toBeNull();
      expect((await claims.claim({ orderId: o1, romoId: romoSama.id, enforceTerritory: true })).claimed).toBe(true);

      const o2 = await order();
      await expect(claims.claim({ orderId: o2, romoId: ordoLain.id, enforceTerritory: true })).rejects.toBeInstanceOf(ForbiddenException);
      expect((await claims.claim({ orderId: o2, romoId: ordoSama.id, enforceTerritory: true })).claimed).toBe(true);

      const o3 = await order();
      expect((await claims.claim({ orderId: o3, romoId: romoLain.id, enforceTerritory: false })).claimed).toBe(true); // Admin/Koordinator
    });

    it('hanya pelayanan PENDING yang dapat diterima: final dan FAIL ditolak dengan alasan status', async () => {
      const umat = await fx.user('UMAT', { parokiId: t.paroki1 });
      const romo = await fx.user('ROMO_PAROKI', { parokiId: t.paroki1 });
      for (const status of ['FAIL', 'DONE', 'CLOSE']) {
        const orderId = await fx.order({ userId: umat.id, parokiId: t.paroki1, status });
        await expect(claims.claim({ orderId, romoId: romo.id, enforceTerritory: true })).rejects.toThrow(new RegExp(`berstatus ${status}`));
      }
      await expect(claims.claim({ orderId: 987654321, romoId: romo.id, enforceTerritory: false })).rejects.toThrow(/tidak ditemukan/);
    });

    it('menerima ulang oleh Romo yang sama: tidak diproses ulang saat berjalan, ditolak bila sudah final', async () => {
      const umat = await fx.user('UMAT', { parokiId: t.paroki1 });
      const romo = await fx.user('ROMO_PAROKI', { parokiId: t.paroki1 });
      const orderId = await fx.order({ userId: umat.id, parokiId: t.paroki1 });
      expect((await claims.claim({ orderId, romoId: romo.id, enforceTerritory: true })).claimed).toBe(true);
      await ds.query(`UPDATE orders SET status = 'CONFIRMED' WHERE id = $1`, [orderId]);
      expect((await claims.claim({ orderId, romoId: romo.id, enforceTerritory: true })).claimed).toBe(false);
      await ds.query(`UPDATE orders SET status = 'DONE' WHERE id = $1`, [orderId]);
      await expect(claims.claim({ orderId, romoId: romo.id, enforceTerritory: true })).rejects.toBeInstanceOf(ConflictException);
    });

    it('release() membatalkan klaim; klaim tingkat misa tidak menyentuh baris order', async () => {
      const umat = await fx.user('UMAT', { parokiId: t.paroki1 });
      const romo = await fx.user('ROMO_PAROKI', { parokiId: t.paroki1 });
      const orderId = await fx.order({ userId: umat.id, parokiId: t.paroki1 });
      const claim = await claims.claim({ orderId, romoId: romo.id, enforceTerritory: true });
      await claim.release();
      expect((await fx.row('orders', orderId)).accepted_romo_id).toBeNull();

      const itemA = await fx.item(orderId);
      const itemB = await fx.item(orderId);
      expect((await claims.claim({ orderId, itemId: itemA, romoId: romo.id, enforceTerritory: true })).claimed).toBe(true);
      expect(Number((await fx.row('order_items', itemA)).accepted_romo_id)).toBe(romo.id);
      expect((await fx.row('order_items', itemB)).accepted_romo_id).toBeNull();
      expect((await fx.row('orders', orderId)).accepted_romo_id).toBeNull();
    });
  });

  describe('OrderGuardsService', () => {
    it('ubah jam: hanya untuk pelayanan CONFIRMED tanpa ajuan lain yang menunggu', async () => {
      const umat = await fx.user('UMAT', { parokiId: t.paroki1 });
      const pending = await fx.order({ userId: umat.id, status: 'PENDING' });
      const done = await fx.order({ userId: umat.id, status: 'DONE' });
      const ok = await fx.order({ userId: umat.id, status: 'CONFIRMED' });
      await expect(guards.assertRescheduleProposable(pending)).rejects.toBeInstanceOf(ConflictException);
      await expect(guards.assertRescheduleProposable(done)).rejects.toBeInstanceOf(ConflictException);
      await expect(guards.assertRescheduleProposable(ok)).resolves.toBeUndefined();
      await ds.query(`UPDATE orders SET reschedule_status = 'PENDING_UMAT' WHERE id = $1`, [ok]);
      await expect(guards.assertRescheduleProposable(ok)).rejects.toThrow(/menunggu respons umat/);
      await expect(guards.assertReschedulePending(ok)).resolves.toBeUndefined();
      await expect(guards.assertReschedulePending(pending)).rejects.toBeInstanceOf(ConflictException);
    });

    it('pelimpahan: target harus Romo aktif lain; nama eksternal wajar; pelayanan harus berjalan', async () => {
      const umat = await fx.user('UMAT', { parokiId: t.paroki1 });
      const romo = await fx.user('ROMO_PAROKI', { parokiId: t.paroki1 });
      const target = await fx.user('ROMO_PAROKI', { parokiId: t.paroki1 });
      const pendingRomo = await fx.user('ROMO_PAROKI', { parokiId: t.paroki1, status: 'PENDING_APPROVAL' });
      const orderId = await fx.order({ userId: umat.id, status: 'CONFIRMED' });
      const allowed = (dto: any, id = orderId) => guards.assertHandoverAllowed(id, null, { romoId: romo.id, ...dto });

      await expect(allowed({ targetRomoId: target.id, reason: 'Berhalangan' })).resolves.toBeUndefined();
      await expect(allowed({})).rejects.toBeInstanceOf(BadRequestException); // tanpa pengganti
      await expect(allowed({ targetRomoId: romo.id })).rejects.toThrow(/tidak boleh sama/); // diri sendiri
      await expect(allowed({ targetRomoId: umat.id })).rejects.toThrow(/tidak valid/); // bukan Romo
      await expect(allowed({ targetRomoId: pendingRomo.id })).rejects.toThrow(/tidak valid/); // belum aktif
      await expect(allowed({ targetRomoId: 987654321 })).rejects.toThrow(/tidak valid/); // tidak ada
      await expect(allowed({ externalRomoName: 'Romo Eksternal' })).resolves.toBeUndefined();
      for (const name of ['ab', 'x'.repeat(101), 'Romo <script>']) await expect(allowed({ externalRomoName: name })).rejects.toBeInstanceOf(BadRequestException);
      await expect(allowed({ targetRomoId: target.id, reason: 'x'.repeat(501) })).rejects.toThrow(/Alasan maksimal/);

      const done = await fx.order({ userId: umat.id, status: 'DONE' });
      await expect(allowed({ targetRomoId: target.id }, done)).rejects.toBeInstanceOf(ConflictException);
      await ds.query(`UPDATE orders SET handover_status = 'PENDING' WHERE id = $1`, [orderId]);
      await expect(allowed({ targetRomoId: target.id })).rejects.toThrow(/menunggu respons/);
      await expect(guards.assertHandoverPending(orderId)).resolves.toBeUndefined();
      await expect(guards.assertHandoverPending(done)).rejects.toBeInstanceOf(ConflictException);
    });

    it('kategori dan urgensi harus ada; kategori nonaktif ditolak', async () => {
      await expect(guards.assertNewOrderRefs({ serviceCategoryId: 1, urgencyLevelId: 1 })).resolves.toBeUndefined();
      await expect(guards.assertNewOrderRefs({ serviceCategoryId: 99999, urgencyLevelId: 1 })).rejects.toThrow(/Kategori/);
      await expect(guards.assertNewOrderRefs({ serviceCategoryId: 1, urgencyLevelId: 99999 })).rejects.toThrow(/urgensi/);
      await ds.query(`UPDATE service_categories SET is_active = FALSE WHERE id = 4`);
      try {
        await expect(guards.assertNewOrderRefs({ serviceCategoryId: 4, urgencyLevelId: 1 })).rejects.toThrow(/tidak aktif/);
      } finally {
        await ds.query(`UPDATE service_categories SET is_active = TRUE WHERE id = 4`);
      }
    });

    it('order atau misa yang tidak ada -> 404', async () => {
      await expect(guards.assertExists(987654321)).rejects.toThrow(/tidak ditemukan/);
      await expect(guards.target(987654321, 5)).rejects.toThrow(/tidak ditemukan/);
    });
  });

  describe('generateOrderNumber', () => {
    it('30 pembuatan serentak menghasilkan nomor unik dan berurutan', async () => {
      const numbers = await Promise.all(Array.from({ length: 30 }, () => generateOrderNumber(ds, 1)));
      expect(new Set(numbers).size).toBe(30);
      for (const n of numbers) expect(n).toMatch(/^SM-\d{8}-\d{4,}$/);
      const seq = numbers.map((n) => Number(n.split('-')[2])).sort((x, y) => x - y);
      expect(seq[29] - seq[0]).toBe(29); // tanpa celah: penghitung atomik
    });

    it('awalan mengikuti jenis pelayanan; nomor lama yang kebetulan sama dilewati', async () => {
      expect(await generateOrderNumber(ds, 2)).toMatch(/^MD-/);
      const umat = await fx.user('UMAT');
      const next = await generateOrderNumber(ds, 1);
      const [prefix, day, seq] = next.split('-');
      const taken = `${prefix}-${day}-${String(Number(seq) + 1).padStart(4, '0')}`;
      const r = await ds.query(
        `INSERT INTO orders (order_number, user_id, service_category_id, urgency_level_id, scheduled_date, scheduled_time, location_name, address_detail, notes) VALUES ($1, $2, 1, 1, CURRENT_DATE, '10:00', 'x', 'x', $3) RETURNING id`,
        [taken, umat.id, `integration-test ${fx.tag}`],
      );
      try {
        const after = await generateOrderNumber(ds, 1);
        expect(after).not.toBe(taken);
        expect(Number(after.split('-')[2])).toBe(Number(seq) + 2);
      } finally {
        await ds.query('DELETE FROM orders WHERE id = $1', [r[0].id]);
      }
    });
  });
});
