import { DataSource } from 'typeorm';
import { EscalationSettingsService } from '../../src/modules/escalation/escalation-settings.service';
import { OrderEventsService } from '../../src/modules/order-events/order-events.service';
import { OrdersService } from '../../src/modules/orders/orders.service';
import { Fixture, connect, describeDb, disconnect } from './db-fixture';

describeDb('Notifikasi pembuatan Misa Kedukaan multi-misa (PostgreSQL sungguhan)', () => {
  let ds: DataSource;
  let fx: Fixture;
  let orders: OrdersService;
  let push: jest.Mock;
  let t: Awaited<ReturnType<Fixture['territory']>>;

  beforeAll(async () => {
    ds = await connect();
    fx = new Fixture(ds);
    push = jest.fn().mockResolvedValue({});
    const fcm = { sendPushToUsers: push } as any;
    orders = new OrdersService(ds, fcm, new EscalationSettingsService(ds), new OrderEventsService(ds, fcm));
    t = await fx.territory();
  });
  afterAll(async () => {
    try {
      await fx.cleanup();
    } finally {
      await disconnect();
    }
  });

  it('3 misa menghasilkan 3 notifikasi dalam aplikasi DAN 3 push per penerima, masing-masing membawa itemId misanya', async () => {
    const umat = await fx.user('UMAT', { parokiId: t.paroki1, kotaId: t.kota1, keuskupanId: t.keuskupan });
    const romo = await fx.user('ROMO_PAROKI', { parokiId: t.paroki1, kotaId: t.kota1, keuskupanId: t.keuskupan });
    const date = new Date(Date.now() + 5 * 86_400_000).toISOString().slice(0, 10);
    const mk = (n: number) => ({ itemName: `Misa Uji ${n}`, scheduledDate: date, scheduledTimeStart: '09:00', scheduledTimeEnd: '10:00', locationName: 'Gereja' });
    push.mockClear();
    const res: any = await orders.createOrder({ userId: umat.id, serviceCategoryId: 2, urgencyLevelId: 1, scheduledDate: date, scheduledTime: '09:00', locationName: 'Rumah Duka', addressDetail: 'Jl. Uji', notes: 'integration-test kedukaan-push', items: [mk(1), mk(2), mk(3)] } as any);
    fx.track(res.order.id);

    const inApp = await ds.query(`SELECT chat_group_id FROM notifications WHERE order_id = $1 AND user_id = $2 AND type = 'NEW_ORDER_ROMO'`, [res.order.id, romo.id]);
    expect(inApp).toHaveLength(3);
    expect(new Set(inApp.map((r: any) => r.chat_group_id)).size).toBe(3);

    const romoPushes = push.mock.calls.filter(([ids, msg]) => (ids as unknown[]).map(Number).includes(romo.id) && msg.data.type === 'NEW_ORDER_ROMO');
    expect(romoPushes).toHaveLength(3);
    const itemIds = romoPushes.map(([, msg]) => msg.data.itemId);
    expect(new Set(itemIds).size).toBe(3);
    expect(itemIds.every((id) => id !== '')).toBe(true);
    expect(romoPushes.map(([, msg]) => msg.title).join('|')).toMatch(/Misa Uji 1.*Misa Uji 2.*Misa Uji 3/);
  });

  it('pelayanan tanpa misa (Perminyakan) tetap satu push', async () => {
    const umat = await fx.user('UMAT', { parokiId: t.paroki1, kotaId: t.kota1, keuskupanId: t.keuskupan });
    const romo = await fx.user('ROMO_PAROKI', { parokiId: t.paroki1, kotaId: t.kota1, keuskupanId: t.keuskupan });
    const date = new Date(Date.now() + 5 * 86_400_000).toISOString().slice(0, 10);
    push.mockClear();
    const res: any = await orders.createOrder({ userId: umat.id, serviceCategoryId: 1, urgencyLevelId: 1, scheduledDate: date, scheduledTime: '09:00', locationName: 'RS', addressDetail: 'Kamar 1', notes: 'integration-test perminyakan-push' } as any);
    fx.track(res.order.id);
    const romoPushes = push.mock.calls.filter(([ids, msg]) => (ids as unknown[]).map(Number).includes(romo.id) && msg.data.type === 'NEW_ORDER_ROMO');
    expect(romoPushes).toHaveLength(1);
    expect(romoPushes[0][1].data.itemId).toBe('');
  });

  it('Pengurus Lingkungan hanya mendapat notifikasi dan grup chat; pelayanan Umat tidak muncul di daftar berandanya', async () => {
    const umat = await fx.user('UMAT', { parokiId: t.paroki1, kotaId: t.kota1, keuskupanId: t.keuskupan });
    const pengurus = await fx.user('PENGURUS_LINGKUNGAN', { parokiId: t.paroki1, kotaId: t.kota1, keuskupanId: t.keuskupan });
    await ds.query('UPDATE user_profiles SET lingkungan_id = 1001 WHERE user_id = ANY($1::int[])', [[umat.id, pengurus.id]]);
    const date = new Date(Date.now() + 5 * 86_400_000).toISOString().slice(0, 10);
    const res: any = await orders.createOrder({ userId: umat.id, serviceCategoryId: 1, urgencyLevelId: 1, lingkunganId: 1001, scheduledDate: date, scheduledTime: '09:00', locationName: 'RS', addressDetail: 'Kamar 1', notes: 'integration-test pengurus-beranda' } as any);
    fx.track(res.order.id);

    const notif = await ds.query(`SELECT 1 FROM notifications WHERE order_id = $1 AND user_id = $2`, [res.order.id, pengurus.id]);
    const member = await ds.query(`SELECT 1 FROM chat_group_members m JOIN chat_groups g ON g.id = m.chat_group_id WHERE g.order_id = $1 AND m.user_id = $2`, [res.order.id, pengurus.id]);
    expect(notif.length).toBeGreaterThan(0);
    expect(member.length).toBeGreaterThan(0);

    const punyaPengurus: any[] = await orders.getOrders(String(pengurus.id));
    expect(punyaPengurus.map((o) => Number(o.id))).not.toContain(Number(res.order.id));
    const punyaUmat: any[] = await orders.getOrders(String(umat.id));
    expect(punyaUmat.map((o) => Number(o.id))).toContain(Number(res.order.id));
  });
});
