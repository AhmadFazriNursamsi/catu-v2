import { ForbiddenException } from '@nestjs/common';
import { DataSource } from 'typeorm';
import { AccessService } from '../../src/common/access/access.service';
import { EscalationService } from '../../src/modules/escalation/escalation.service';
import { EscalationSettingsService } from '../../src/modules/escalation/escalation-settings.service';
import { OrderEventsService } from '../../src/modules/order-events/order-events.service';
import { AcceptanceClaimService } from '../../src/modules/order-rules/acceptance-claim.service';
import { LintasParokiService } from '../../src/modules/order-rules/lintas-paroki.service';
import { OrdersService } from '../../src/modules/orders/orders.service';
import { Fixture, connect, describeDb, disconnect } from './db-fixture';

/**
 * Pelayanan lintas paroki (paroki penerima berbeda dari paroki pemohon): hanya Romo Ordo tujuan, tanpa jeda;
 * Romo Paroki tidak berwenang; pengurus pemohon tetap memantau; Koordinator pemohon dan tujuan masuk grup chat.
 */
describeDb('Pelayanan lintas paroki (PostgreSQL sungguhan)', () => {
  let ds: DataSource;
  let fx: Fixture;
  let lintas: LintasParokiService;
  let claims: AcceptanceClaimService;
  let access: AccessService;
  let escalation: EscalationService;
  let orders: OrdersService;
  let t: Awaited<ReturnType<Fixture['territory']>>;

  beforeAll(async () => {
    ds = await connect();
    fx = new Fixture(ds);
    const fcm = { sendPushToUsers: jest.fn().mockResolvedValue({}) } as any;
    const events = new OrderEventsService(ds, fcm);
    const settings = new EscalationSettingsService(ds);
    lintas = new LintasParokiService(ds, events);
    claims = new AcceptanceClaimService(ds);
    access = new AccessService(ds);
    escalation = new EscalationService(ds, settings, events);
    orders = new OrdersService(ds, fcm, settings, events);
    t = await fx.territory();
    if (!t.parokiLain) throw new Error('Butuh paroki di keuskupan lain pada data master.');
  });
  afterAll(async () => {
    try {
      await fx.cleanup();
    } finally {
      await disconnect();
    }
  });

  /** Pemohon di paroki1; pelayanan untuk paroki2 (kota2) yang dibuat sebagai pelayanan baru (belum ditandai lintas). */
  async function scene(tujuanParoki = t.paroki2, tujuanKeuskupan = t.keuskupan) {
    const pemohon = await fx.user('UMAT', { parokiId: t.paroki1, kotaId: t.kota1, keuskupanId: t.keuskupan });
    const orderId = await fx.order({ userId: pemohon.id, parokiId: tujuanParoki, kotaId: t.kota2, keuskupanId: t.keuskupan });
    const group = await fx.chatGroup(orderId);
    return { pemohon, orderId, group, tujuanKeuskupan };
  }
  const notified = async (orderId: number, type: string) =>
    (await ds.query('SELECT user_id FROM notifications WHERE order_id = $1 AND type = $2', [orderId, type])).map((r: { user_id: string }) => Number(r.user_id));
  const members = async (group: number, role: string) =>
    (await ds.query('SELECT user_id FROM chat_group_members WHERE chat_group_id = $1 AND role_in_group = $2', [group, role])).map((r: { user_id: string }) => Number(r.user_id));

  it('afterCreate menandai pelayanan lintas paroki, membuka Romo Ordo tujuan tanpa jeda, dan hanya Romo Ordo kota tujuan diberi tahu', async () => {
    const { orderId } = await scene();
    const ordoTujuan = await fx.user('ROMO_ORDO', { kotaId: t.kota2 });
    const ordoLain = await fx.user('ROMO_ORDO', { kotaId: t.kota1 });
    expect(await lintas.afterCreate(orderId)).toBe(true);
    const row = await fx.row('orders', orderId);
    expect(row.lintas_paroki).toBe(true);
    expect(row.ordo_notified_at).not.toBeNull(); // tidak menunggu jeda eskalasi
    const ordo = await notified(orderId, 'NEW_ORDER_ROMO');
    expect(ordo).toContain(ordoTujuan.id);
    expect(ordo).not.toContain(ordoLain.id);
  });

  it('pelayanan di paroki yang sama dengan pemohon bukan lintas: tidak diubah dan tidak ada notifikasi', async () => {
    const pemohon = await fx.user('UMAT', { parokiId: t.paroki1, kotaId: t.kota1, keuskupanId: t.keuskupan });
    const orderId = await fx.order({ userId: pemohon.id, parokiId: t.paroki1, kotaId: t.kota1, keuskupanId: t.keuskupan });
    expect(await lintas.afterCreate(orderId)).toBe(false);
    expect((await fx.row('orders', orderId)).lintas_paroki).toBe(false);
    expect(await notified(orderId, 'NEW_ORDER_ROMO')).toEqual([]);
  });

  it('Koordinator keuskupan pemohon DAN keuskupan tujuan masuk grup chat dan diberi tahu; keuskupan lain tidak', async () => {
    const { orderId, group } = await scene(t.parokiLain as number);
    const koorPemohon = await fx.user('KOORDINATOR_KEUSKUPAN', { keuskupanId: t.keuskupan });
    const koorTujuan = await fx.user('KOORDINATOR_KEUSKUPAN', { keuskupanId: t.keuskupanLain as number });
    const koorLain = await fx.user('KOORDINATOR_KEUSKUPAN', { keuskupanId: await otherKeuskupan() });
    expect(await lintas.afterCreate(orderId)).toBe(true);

    const inGroup = await members(group, 'KOORDINATOR');
    expect(inGroup).toEqual(expect.arrayContaining([koorPemohon.id, koorTujuan.id]));
    expect(inGroup).not.toContain(koorLain.id);
    const notif = await notified(orderId, 'NEW_ORDER_KOORDINATOR');
    expect(notif).toEqual(expect.arrayContaining([koorPemohon.id, koorTujuan.id]));
    expect(notif).not.toContain(koorLain.id);
    const msg = await ds.query(`SELECT message FROM chat_messages WHERE chat_group_id = $1 AND message_type = 'SYSTEM_EVENT'`, [group]);
    expect(msg.some((m: { message: string }) => /Romo Ordo tujuan/.test(m.message))).toBe(true);
  });

  async function otherKeuskupan(): Promise<number> {
    const r = await ds.query('SELECT id FROM keuskupan WHERE id NOT IN ($1, $2) ORDER BY id LIMIT 1', [t.keuskupan, t.keuskupanLain]);
    return Number(r[0].id);
  }

  it('Romo Paroki mana pun tidak berwenang (tujuan maupun asal); Romo Ordo kota tujuan berwenang; kota lain tidak', async () => {
    const { pemohon, orderId } = await scene();
    await lintas.afterCreate(orderId);
    const romoTujuan = await fx.user('ROMO_PAROKI', { parokiId: t.paroki2 });
    const romoAsal = await fx.user('ROMO_PAROKI', { parokiId: t.paroki1 });
    const ordoTujuan = await fx.user('ROMO_ORDO', { kotaId: t.kota2 });
    const ordoLain = await fx.user('ROMO_ORDO', { kotaId: t.kota1 });
    for (const romo of [romoTujuan, romoAsal]) {
      await expect(claims.claim({ orderId, romoId: romo.id, enforceTerritory: true })).rejects.toThrow(/Romo Paroki tidak berwenang/);
    }
    await expect(claims.claim({ orderId, romoId: ordoLain.id, enforceTerritory: true })).rejects.toBeInstanceOf(ForbiddenException);
    expect((await claims.claim({ orderId, romoId: ordoTujuan.id, enforceTerritory: true })).claimed).toBe(true);
    expect(pemohon.id).toBeGreaterThan(0);
  });

  it('Romo Ordo tujuan dapat menerima segera (tanpa jeda); tanpa tanda lintas ia harus menunggu jeda eskalasi', async () => {
    const { orderId } = await scene();
    const ordo = await fx.user('ROMO_ORDO', { kotaId: t.kota2 });
    await escalation['settings'].update({ ordoAfterMinutes: 10, koordinatorAfterMinutes: 20 }).catch(() => undefined);
    // belum lintas: pelayanan baru masih menunggu Romo Paroki
    await expect(escalation.assertCanAccept({ sub: ordo.id, roleCode: 'ROMO_ORDO' }, orderId, 'CONFIRMED')).rejects.toThrow(/menunggu Romo Paroki/);
    await lintas.afterCreate(orderId);
    await expect(escalation.assertCanAccept({ sub: ordo.id, roleCode: 'ROMO_ORDO' }, orderId, 'CONFIRMED')).resolves.toBeUndefined();
  });

  it('daftar pelayanan: Romo Paroki tujuan tidak melihat, Romo Ordo kota tujuan langsung melihat, pengurus pemohon tetap melihat', async () => {
    const { pemohon, orderId } = await scene();
    await lintas.afterCreate(orderId);
    const romoTujuan = await fx.user('ROMO_PAROKI', { parokiId: t.paroki2 });
    const ordoTujuan = await fx.user('ROMO_ORDO', { kotaId: t.kota2 });
    const ids = async (romoId: number) => ((await orders.getOrders(undefined, undefined, String(romoId))) as Array<{ id: number }>).map((o) => Number(o.id));
    expect(await ids(romoTujuan.id)).not.toContain(orderId);
    expect(await ids(ordoTujuan.id)).toContain(orderId);

    // kontrol: pelayanan biasa (bukan lintas) di paroki2 tetap terlihat oleh Romo Paroki 2
    const pemohon2 = await fx.user('UMAT', { parokiId: t.paroki2, kotaId: t.kota2, keuskupanId: t.keuskupan });
    const biasa = await fx.order({ userId: pemohon2.id, parokiId: t.paroki2, kotaId: t.kota2, keuskupanId: t.keuskupan });
    expect(await ids(romoTujuan.id)).toContain(biasa);
    expect(pemohon.id).toBeGreaterThan(0);
  });

  it('akses chat Koordinator: keuskupan tujuan hanya untuk pelayanan lintas; keuskupan lain tidak pernah', async () => {
    const { orderId, group } = await scene(t.parokiLain as number);
    const koorTujuan = await fx.user('KOORDINATOR_KEUSKUPAN', { keuskupanId: t.keuskupanLain as number });
    const koorPemohon = await fx.user('KOORDINATOR_KEUSKUPAN', { keuskupanId: t.keuskupan });
    const koorLain = await fx.user('KOORDINATOR_KEUSKUPAN', { keuskupanId: await otherKeuskupan() });

    // sebelum ditandai lintas: hanya Koordinator keuskupan pemohon
    expect(await access.koordinatorSharesKeuskupan(koorPemohon.id, group)).toBe(true);
    expect(await access.koordinatorSharesKeuskupan(koorTujuan.id, group)).toBe(false);
    await lintas.afterCreate(orderId);
    expect(await access.koordinatorSharesKeuskupan(koorTujuan.id, group)).toBe(true);
    expect(await access.koordinatorSharesKeuskupan(koorPemohon.id, group)).toBe(true);
    expect(await access.koordinatorSharesKeuskupan(koorLain.id, group)).toBe(false);
  });
});
