import { DataSource } from 'typeorm';
import { AssignmentsService } from '../../src/modules/assignments/assignments.service';
import { OrdersService } from '../../src/modules/orders/orders.service';
import { EscalationSettingsService } from '../../src/modules/escalation/escalation-settings.service';
import { OrderEventsService } from '../../src/modules/order-events/order-events.service';
import { deriveOrderStatus, orderStatusFromItemsSql } from '../../src/modules/order-rules/order-status-derive';
import { Fixture, connect, describeDb, disconnect } from './db-fixture';

const STATUSES = ['PENDING', 'CONFIRMED', 'IN_PROGRESS', 'DONE', 'CLOSE', 'FAIL'];

function multisets(size: number, from = 0): string[][] {
  if (size === 0) return [[]];
  const out: string[][] = [];
  for (let i = from; i < STATUSES.length; i++) for (const rest of multisets(size - 1, i)) out.push([STATUSES[i], ...rest]);
  return out;
}

describeDb('Status pelayanan induk diturunkan dari misanya (PostgreSQL sungguhan)', () => {
  let ds: DataSource;
  let fx: Fixture;
  let orders: OrdersService;
  let assignments: AssignmentsService;
  let t: Awaited<ReturnType<Fixture['territory']>>;

  beforeAll(async () => {
    ds = await connect();
    fx = new Fixture(ds);
    const fcm = { sendPushToUsers: jest.fn().mockResolvedValue({}) } as any;
    orders = new OrdersService(ds, fcm, new EscalationSettingsService(ds), new OrderEventsService(ds, fcm));
    assignments = new AssignmentsService(ds, fcm);
    t = await fx.territory();
  });
  afterAll(async () => {
    try {
      await fx.cleanup();
    } finally {
      await disconnect();
    }
  });

  const sync = () => {
    (orders as any).lastStatusSyncDate = '';
    return (orders as any).autoSyncOrderStatuses();
  };

  it('SQL setara fungsi murni untuk semua kombinasi status 1-3 misa', async () => {
    const umat = await fx.user('UMAT', { parokiId: t.paroki1 });
    const orderId = await fx.order({ userId: umat.id, parokiId: t.paroki1, categoryId: 2 });
    let checked = 0;
    for (const combo of [...multisets(1), ...multisets(2), ...multisets(3)]) {
      await ds.query('DELETE FROM order_items WHERE order_id = $1', [orderId]);
      for (const st of combo) await fx.item(orderId, st);
      const [row] = await ds.query(`SELECT ${orderStatusFromItemsSql('$1')} AS st`, [orderId]);
      expect({ combo, st: row.st }).toEqual({ combo, st: deriveOrderStatus(combo) });
      checked++;
    }
    expect(checked).toBe(6 + 21 + 56);
    await ds.query('DELETE FROM order_items WHERE order_id = $1', [orderId]);
    const [none] = await ds.query(`SELECT ${orderStatusFromItemsSql('$1')} AS st`, [orderId]);
    expect(none.st).toBeNull();
  });

  it('misa 1 DONE dan misa 2 CLOSE: pelayanan menjadi DONE, bukan PENDING (F8)', async () => {
    const umat = await fx.user('UMAT', { parokiId: t.paroki1 });
    const romo = await fx.user('ROMO_PAROKI', { parokiId: t.paroki1 });
    const orderId = await fx.order({ userId: umat.id, parokiId: t.paroki1, categoryId: 2, status: 'CONFIRMED' });
    const a = await fx.item(orderId, 'CONFIRMED', 5, romo.id);
    const b = await fx.item(orderId, 'CONFIRMED', 6, romo.id);
    await assignments.respondAssignment(String(orderId), { status: 'DONE', romoId: romo.id, itemId: a } as any);
    expect((await fx.row('orders', orderId)).status_text).toBe('CONFIRMED');
    await assignments.respondAssignment(String(orderId), { status: 'CLOSE', romoId: romo.id, itemId: b } as any);
    expect((await fx.row('orders', orderId)).status_text).toBe('DONE');
  });

  it('sinkron otomatis: misa pertama lewat tanpa Romo tidak menggagalkan pelayanan yang masih punya misa mendatang (J2)', async () => {
    const umat = await fx.user('UMAT', { parokiId: t.paroki1 });
    const orderId = await fx.order({ userId: umat.id, parokiId: t.paroki1, categoryId: 2, scheduledDate: new Date(Date.now() - 3 * 86_400_000).toISOString().slice(0, 10) });
    const lewat = await fx.item(orderId, 'PENDING', -3);
    const depan = await fx.item(orderId, 'PENDING', 5);
    await sync();
    expect((await fx.row('order_items', lewat)).status_text).toBe('FAIL');
    expect((await fx.row('order_items', depan)).status_text).toBe('PENDING');
    expect((await fx.row('orders', orderId)).status_text).toBe('PENDING');
  });

  it('sinkron otomatis: misa pertama diterima lalu lewat tidak menutup pelayanan yang masih punya misa aktif (J5)', async () => {
    const umat = await fx.user('UMAT', { parokiId: t.paroki1 });
    const romo = await fx.user('ROMO_PAROKI', { parokiId: t.paroki1 });
    const orderId = await fx.order({ userId: umat.id, parokiId: t.paroki1, categoryId: 2, status: 'CONFIRMED', scheduledDate: new Date(Date.now() - 3 * 86_400_000).toISOString().slice(0, 10) });
    const lewat = await fx.item(orderId, 'CONFIRMED', -3, romo.id);
    const depan = await fx.item(orderId, 'CONFIRMED', 5, romo.id);
    await sync();
    expect((await fx.row('order_items', lewat)).status_text).toBe('CLOSE');
    expect((await fx.row('order_items', depan)).status_text).toBe('CONFIRMED');
    expect((await fx.row('orders', orderId)).status_text).toBe('CONFIRMED');
  });

  it('sinkron otomatis: semua misa lewat menutup/menggagalkan pelayanan; pelayanan tanpa misa tetap mengikuti tanggalnya', async () => {
    const umat = await fx.user('UMAT', { parokiId: t.paroki1 });
    const romo = await fx.user('ROMO_PAROKI', { parokiId: t.paroki1 });
    const past = new Date(Date.now() - 3 * 86_400_000).toISOString().slice(0, 10);
    const gagal = await fx.order({ userId: umat.id, parokiId: t.paroki1, categoryId: 2, scheduledDate: past });
    await fx.item(gagal, 'PENDING', -3);
    await fx.item(gagal, 'PENDING', -2);
    const tutup = await fx.order({ userId: umat.id, parokiId: t.paroki1, categoryId: 2, status: 'CONFIRMED', scheduledDate: past });
    await fx.item(tutup, 'CONFIRMED', -3, romo.id);
    await fx.item(tutup, 'CONFIRMED', -2, romo.id);
    const tanpaMisa = await fx.order({ userId: umat.id, parokiId: t.paroki1, scheduledDate: past });
    await sync();
    expect((await fx.row('orders', gagal)).status_text).toBe('FAIL');
    expect((await fx.row('orders', tutup)).status_text).toBe('CLOSE');
    expect((await fx.row('orders', tanpaMisa)).status_text).toBe('FAIL');
  });
});
