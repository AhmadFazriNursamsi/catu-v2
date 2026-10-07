import { ConflictException } from '@nestjs/common';
import { DataSource } from 'typeorm';
import { EscalationSettingsService } from '../../src/modules/escalation/escalation-settings.service';
import { OrderEventsService } from '../../src/modules/order-events/order-events.service';
import { OrderGuardsService } from '../../src/modules/order-rules/order-guards.service';
import { OrdersService } from '../../src/modules/orders/orders.service';
import { Fixture, connect, describeDb, disconnect } from './db-fixture';

describeDb('Ubah jam: hanya jam, dengan status ajuan (PostgreSQL sungguhan)', () => {
  let ds: DataSource;
  let fx: Fixture;
  let orders: OrdersService;
  let guards: OrderGuardsService;
  let t: Awaited<ReturnType<Fixture['territory']>>;

  beforeAll(async () => {
    ds = await connect();
    fx = new Fixture(ds);
    const fcm = { sendPushToUsers: jest.fn().mockResolvedValue({}) } as any;
    orders = new OrdersService(ds, fcm, new EscalationSettingsService(ds), new OrderEventsService(ds, fcm));
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

  async function confirmedOrderWithTwoMisa() {
    const umat = await fx.user('UMAT', { parokiId: t.paroki1 });
    const romo = await fx.user('ROMO_PAROKI', { parokiId: t.paroki1 });
    const orderId = await fx.order({ userId: umat.id, parokiId: t.paroki1, categoryId: 2, status: 'CONFIRMED' });
    const a = await fx.item(orderId, 'CONFIRMED', 4, romo.id);
    const b = await fx.item(orderId, 'CONFIRMED', 6, romo.id);
    return { umat, romo, orderId, a, b };
  }
  const propose = (orderId: number, romoId: number, itemId: number, start = '19:00') =>
    orders.proposeReschedule(String(orderId), { romoId, itemId, newTimeStart: start, newTimeEnd: '20:00', reason: 'Menyesuaikan dengan keluarga duka' });

  it('status ajuan: NONE -> PENDING_UMAT (diajukan) -> ACCEPTED (diterima) atau REJECTED (ditolak), per misa', async () => {
    const { umat, romo, orderId, a, b } = await confirmedOrderWithTwoMisa();
    expect((await fx.row('order_items', a)).reschedule_status).toBe('NONE');
    await propose(orderId, romo.id, a);
    expect((await fx.row('order_items', a)).reschedule_status).toBe('PENDING_UMAT');
    expect((await fx.row('order_items', b)).reschedule_status).toBe('NONE'); // misa lain tidak ikut
    await orders.respondReschedule(String(orderId), { userId: umat.id, itemId: a, action: 'REJECT' });
    expect((await fx.row('order_items', a)).reschedule_status).toBe('REJECTED');
    await propose(orderId, romo.id, a, '19:30');
    await orders.respondReschedule(String(orderId), { userId: umat.id, itemId: a, action: 'ACCEPT' });
    expect((await fx.row('order_items', a)).reschedule_status).toBe('ACCEPTED');
  });

  it('diterima: hanya jam misa itu yang berubah; tanggal misa dan jadwal tingkat order tidak tertimpa', async () => {
    const { umat, romo, orderId, a, b } = await confirmedOrderWithTwoMisa();
    const before = { a: await fx.row('order_items', a), b: await fx.row('order_items', b), o: await fx.row('orders', orderId) };
    await propose(orderId, romo.id, b);
    await orders.respondReschedule(String(orderId), { userId: umat.id, itemId: b, action: 'ACCEPT' });
    const after = { a: await fx.row('order_items', a), b: await fx.row('order_items', b), o: await fx.row('orders', orderId) };
    expect(String(after.b.scheduled_date)).toBe(String(before.b.scheduled_date)); // tanggal tetap
    expect(String(after.b.scheduled_time_start).slice(0, 5)).toBe('19:00');
    expect(String(after.b.scheduled_time_end).slice(0, 5)).toBe('20:00');
    expect(String(after.a.scheduled_time_start)).toBe(String(before.a.scheduled_time_start)); // misa lain tetap
    expect(String(after.o.scheduled_date)).toBe(String(before.o.scheduled_date)); // order tidak mengikuti misa 2 (D14)
    expect(String(after.o.scheduled_time)).toBe(String(before.o.scheduled_time));
  });

  it('tanggal yang diajukan dibaca dari jadwal misa itu sendiri (bukan tanggal order)', async () => {
    const { orderId, a, b } = await confirmedOrderWithTwoMisa();
    expect(await guards.scheduledDate(orderId, a)).not.toBe(await guards.scheduledDate(orderId, b));
    expect(await guards.scheduledDate(orderId, b)).toMatch(/^\d{4}-\d{2}-\d{2}$/);
  });

  it('tidak berlaku bila pelayanan sudah selesai atau ditutup: ajuan menunggu tidak dapat ditanggapi lagi', async () => {
    const { romo, orderId, a, b } = await confirmedOrderWithTwoMisa();
    await propose(orderId, romo.id, a);
    await propose(orderId, romo.id, b);
    await guards.assertReschedulePending(orderId, a); // masih berlaku
    await ds.query(`UPDATE order_items SET status = 'DONE' WHERE id = $1`, [a]);
    await ds.query(`UPDATE order_items SET status = 'CLOSE' WHERE id = $1`, [b]);
    await expect(guards.assertReschedulePending(orderId, a)).rejects.toBeInstanceOf(ConflictException);
    await expect(guards.assertReschedulePending(orderId, b)).rejects.toThrow(/sudah selesai atau ditutup/);
  });
});
