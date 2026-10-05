import { ConflictException, ForbiddenException } from '@nestjs/common';
import { DataSource } from 'typeorm';
import { AssignmentWorkflowService } from '../../src/modules/assignments/assignment-workflow.service';
import { AssignmentsService } from '../../src/modules/assignments/assignments.service';
import { AcceptanceClaimService } from '../../src/modules/order-rules/acceptance-claim.service';
import { OrderGuardsService } from '../../src/modules/order-rules/order-guards.service';
import { Fixture, FixtureUser, connect, describeDb, disconnect } from './db-fixture';

describeDb('Alur penerimaan dan status pelayanan (PostgreSQL sungguhan)', () => {
  let ds: DataSource;
  let fx: Fixture;
  let workflow: AssignmentWorkflowService;
  let t: Awaited<ReturnType<Fixture['territory']>>;

  const respond = (orderId: number, status: string, romo: FixtureUser | null, extra: Record<string, unknown> = {}, isAdmin = false) =>
    workflow.respond(orderId, { status, romoId: romo?.id, ...extra } as any, { romoId: romo?.id ?? null, isAdmin });
  const statusOf = async (orderId: number) => ((await fx.row('orders', orderId)) as { status_text: string }).status_text;
  const notificationCount = async (userId: number, orderId: number) => Number((await ds.query('SELECT COUNT(*)::int AS n FROM notifications WHERE user_id = $1 AND order_id = $2', [userId, orderId]))[0].n);

  beforeAll(async () => {
    ds = await connect();
    fx = new Fixture(ds);
    const fcm = { sendPushToUsers: jest.fn().mockResolvedValue({ successCount: 0, failureCount: 0 }) };
    workflow = new AssignmentWorkflowService(ds, new AssignmentsService(ds, fcm as any), new AcceptanceClaimService(ds), new OrderGuardsService(ds));
    t = await fx.territory();
  });
  afterAll(async () => {
    try {
      await fx.cleanup();
    } finally {
      await disconnect();
    }
  });

  async function scene() {
    const umat = await fx.user('UMAT', { parokiId: t.paroki1 });
    const romo = await fx.user('ROMO_PAROKI', { parokiId: t.paroki1 });
    const rekan = await fx.user('ROMO_PAROKI', { parokiId: t.paroki1 });
    const orderId = await fx.order({ userId: umat.id, parokiId: t.paroki1 });
    return { umat, romo, rekan, orderId };
  }

  it('alur lengkap: terima -> berlangsung -> selesai; penerima ditetapkan dan umat diberi tahu', async () => {
    const { umat, romo, orderId } = await scene();
    const res: any = await respond(orderId, 'CONFIRMED', romo);
    expect(res.status).toBe('CONFIRMED');
    expect(await statusOf(orderId)).toBe('CONFIRMED');
    expect(Number((await fx.row('orders', orderId)).accepted_romo_id)).toBe(romo.id);
    expect(await notificationCount(umat.id, orderId)).toBeGreaterThan(0);

    await respond(orderId, 'IN_PROGRESS', romo);
    expect(await statusOf(orderId)).toBe('IN_PROGRESS');
    await respond(orderId, 'DONE', romo);
    expect(await statusOf(orderId)).toBe('DONE');
  });

  it('dua Romo menerima bersamaan lewat alur kerja: satu berhasil, satu 409, hanya pemenang masuk grup chat (10 percobaan)', async () => {
    for (let i = 0; i < 10; i++) {
      const { romo, rekan, orderId } = await scene();
      const group = await fx.chatGroup(orderId);
      const results = await Promise.allSettled([respond(orderId, 'CONFIRMED', romo), respond(orderId, 'CONFIRMED', rekan)]);
      expect(results.filter((r) => r.status === 'fulfilled')).toHaveLength(1);
      const lost = results.find((r) => r.status === 'rejected') as PromiseRejectedResult;
      expect(lost.reason).toBeInstanceOf(ConflictException);
      expect(lost.reason.message).toMatch(/sudah diterima oleh Romo lain/);
      const winner = results[0].status === 'fulfilled' ? romo.id : rekan.id;
      expect(Number((await fx.row('orders', orderId)).accepted_romo_id)).toBe(winner);
      const members = await ds.query(`SELECT user_id FROM chat_group_members WHERE chat_group_id = $1 AND role_in_group LIKE 'ROMO%'`, [group]);
      expect(members.map((m: { user_id: string }) => Number(m.user_id))).toEqual([winner]);
    }
  });

  it('Romo di luar paroki ditolak 403 dan pelayanan tetap PENDING; Admin boleh menerima atas nama Romo', async () => {
    const umat = await fx.user('UMAT', { parokiId: t.paroki1 });
    const luar = await fx.user('ROMO_PAROKI', { parokiId: t.paroki2 });
    const orderId = await fx.order({ userId: umat.id, parokiId: t.paroki1 });
    await expect(respond(orderId, 'CONFIRMED', luar)).rejects.toBeInstanceOf(ForbiddenException);
    expect(await statusOf(orderId)).toBe('PENDING');
    expect((await fx.row('orders', orderId)).accepted_romo_id).toBeNull();
    await respond(orderId, 'CONFIRMED', luar, {}, true);
    expect(await statusOf(orderId)).toBe('CONFIRMED');
  });

  it('status final tidak dapat dimundurkan atau diubah; menerima lagi tidak menggandakan notifikasi', async () => {
    const { umat, romo, orderId } = await scene();
    await respond(orderId, 'CONFIRMED', romo);
    const before = await notificationCount(umat.id, orderId);
    const again: any = await respond(orderId, 'CONFIRMED', romo);
    expect(again.message).toMatch(/sudah menerima pelayanan ini/);
    expect(await notificationCount(umat.id, orderId)).toBe(before); // tidak ada notifikasi ganda

    await respond(orderId, 'DONE', romo);
    for (const status of ['CONFIRMED', 'IN_PROGRESS', 'CLOSE']) {
      await expect(respond(orderId, status, romo)).rejects.toBeInstanceOf(ConflictException);
    }
    const noop: any = await respond(orderId, 'DONE', romo); // mengulang status sama: tanpa efek
    expect(noop.message).toMatch(/sudah berstatus DONE/);
    expect(await statusOf(orderId)).toBe('DONE');
  });

  it('hanya Romo yang bertugas yang boleh mengubah status; melompat dari PENDING ditolak', async () => {
    const { romo, rekan, orderId } = await scene();
    await expect(respond(orderId, 'DONE', romo)).rejects.toBeInstanceOf(ForbiddenException); // belum bertugas
    await respond(orderId, 'CONFIRMED', romo);
    await expect(respond(orderId, 'DONE', rekan)).rejects.toBeInstanceOf(ForbiddenException);
    await expect(respond(orderId, 'FAIL', romo)).rejects.toBeInstanceOf(ConflictException); // FAIL hanya Admin
    expect(await statusOf(orderId)).toBe('CONFIRMED');
  });

  it('FAIL hanya oleh Admin dan hanya dari PENDING; pelayanan FAIL tidak dapat diterima', async () => {
    const { romo, orderId } = await scene();
    await respond(orderId, 'FAIL', null, {}, true);
    expect(await statusOf(orderId)).toBe('FAIL');
    await expect(respond(orderId, 'CONFIRMED', romo)).rejects.toThrow(/berstatus FAIL/);
    const confirmed = (await scene());
    await respond(confirmed.orderId, 'CONFIRMED', confirmed.romo);
    await expect(respond(confirmed.orderId, 'FAIL', null, {}, true)).rejects.toBeInstanceOf(ConflictException);
  });

  it('penerimaan per misa: misa lain tetap PENDING dan dapat diterima Romo lain', async () => {
    const { romo, rekan, orderId } = await scene();
    const itemA = await fx.item(orderId);
    const itemB = await fx.item(orderId);
    await respond(orderId, 'CONFIRMED', romo, { itemId: itemA });
    await expect(respond(orderId, 'CONFIRMED', rekan, { itemId: itemA })).rejects.toBeInstanceOf(ConflictException);
    await respond(orderId, 'CONFIRMED', rekan, { itemId: itemB });
    expect(Number((await fx.row('order_items', itemA)).accepted_romo_id)).toBe(romo.id);
    expect(Number((await fx.row('order_items', itemB)).accepted_romo_id)).toBe(rekan.id);
  });

  it('akun yang bukan Romo aktif tidak dapat menjadi penerima, termasuk atas nama Admin', async () => {
    const { umat, orderId } = await scene();
    await expect(respond(orderId, 'CONFIRMED', umat, {}, true)).rejects.toThrow(/Romo tidak ditemukan atau belum aktif/);
    const pending = await fx.user('ROMO_PAROKI', { parokiId: t.paroki1, status: 'PENDING_APPROVAL' });
    await expect(respond(orderId, 'CONFIRMED', pending, {}, true)).rejects.toThrow(/belum aktif/);
    expect(await statusOf(orderId)).toBe('PENDING');
  });
});
