import { BadRequestException, ConflictException } from '@nestjs/common';
import { DataSource } from 'typeorm';
import { OrderReviewsService } from '../../src/modules/orders/order-reviews.service';
import { Fixture, connect, describeDb, disconnect } from './db-fixture';

describeDb('Ulasan pelayanan (PostgreSQL sungguhan)', () => {
  let ds: DataSource;
  let fx: Fixture;
  let reviews: OrderReviewsService;
  let t: Awaited<ReturnType<Fixture['territory']>>;

  beforeAll(async () => {
    ds = await connect();
    fx = new Fixture(ds);
    reviews = new OrderReviewsService(ds, { sendPushToUsers: jest.fn().mockResolvedValue({}) } as any);
    t = await fx.territory();
  });
  afterAll(async () => {
    try {
      await fx.cleanup();
    } finally {
      await disconnect();
    }
  });

  async function doneOrder() {
    const umat = await fx.user('UMAT', { parokiId: t.paroki1 });
    const romo = await fx.user('ROMO_PAROKI', { parokiId: t.paroki1 });
    const orderId = await fx.order({ userId: umat.id, parokiId: t.paroki1, status: 'DONE' });
    await ds.query('UPDATE orders SET accepted_romo_id = $1 WHERE id = $2', [romo.id, orderId]);
    return { umat, romo, orderId };
  }

  it('ulasan sah tersimpan, dan Romo mendapat notifikasi in-app bertipe ORDER_REVIEW yang menaut ke order', async () => {
    const { umat, romo, orderId } = await doneOrder();
    const res = await reviews.submitReview(String(orderId), { userId: umat.id, rating: 5, reviewNotes: '  Pelayanan khidmat  ' });
    expect(res.success).toBe(true);
    const order = await fx.row('orders', orderId);
    expect(order.rating).toBe(5);
    expect(order.review_notes).toBe('Pelayanan khidmat');
    expect(order.reviewed_at).not.toBeNull();
    const notif = await ds.query(`SELECT type, order_id FROM notifications WHERE user_id = $1 AND order_id = $2`, [romo.id, orderId]);
    expect(notif).toHaveLength(1);
    expect(notif[0].type).toBe('ORDER_REVIEW');
  });

  it('rating di luar 1-5 atau bukan bilangan bulat ditolak dan tidak tersimpan', async () => {
    const { umat, orderId } = await doneOrder();
    for (const rating of [0, 6, 9, -1, 2.5]) {
      await expect(reviews.submitReview(String(orderId), { userId: umat.id, rating, reviewNotes: 'x' })).rejects.toBeInstanceOf(BadRequestException);
    }
    expect((await fx.row('orders', orderId)).rating).toBeNull();
  });

  it('ulasan kedua ditolak 409 dan tidak menimpa yang pertama', async () => {
    const { umat, orderId } = await doneOrder();
    await reviews.submitReview(String(orderId), { userId: umat.id, rating: 5, reviewNotes: 'Pertama' });
    await expect(reviews.submitReview(String(orderId), { userId: umat.id, rating: 1, reviewNotes: 'Kedua' })).rejects.toBeInstanceOf(ConflictException);
    const order = await fx.row('orders', orderId);
    expect(order.rating).toBe(5);
    expect(order.review_notes).toBe('Pertama');
  });

  it('hanya setelah selesai/ditutup, hanya oleh pemohon, dan ulasan wajib berisi', async () => {
    const umat = await fx.user('UMAT', { parokiId: t.paroki1 });
    const lain = await fx.user('UMAT', { parokiId: t.paroki1 });
    const confirmed = await fx.order({ userId: umat.id, status: 'CONFIRMED' });
    await expect(reviews.submitReview(String(confirmed), { userId: umat.id, rating: 5, reviewNotes: 'x' })).rejects.toThrow(/setelah pelayanan selesai/);
    const { orderId } = await doneOrder();
    await expect(reviews.submitReview(String(orderId), { userId: lain.id, rating: 5, reviewNotes: 'x' })).rejects.toThrow(/pemohon/);
    const owner = (await ds.query('SELECT user_id FROM orders WHERE id = $1', [orderId]))[0].user_id;
    await expect(reviews.submitReview(String(orderId), { userId: Number(owner), rating: 5, reviewNotes: '   ' })).rejects.toThrow(/kosong/);
    await expect(reviews.submitReview('abc', { userId: Number(owner), rating: 5, reviewNotes: 'x' })).rejects.toBeInstanceOf(BadRequestException);
  });

  it('ulasan pada misa tertentu hanya menandai misa itu dan tidak dapat diulang', async () => {
    const { umat, orderId } = await doneOrder();
    const itemA = await fx.item(orderId, 'DONE');
    const itemB = await fx.item(orderId, 'DONE');
    await reviews.submitReview(String(orderId), { userId: umat.id, itemId: itemA, rating: 4, reviewNotes: 'Misa pertama' });
    expect((await fx.row('order_items', itemA)).rating).toBe(4);
    expect((await fx.row('order_items', itemB)).rating).toBeNull();
    await expect(reviews.submitReview(String(orderId), { userId: umat.id, itemId: itemA, rating: 1, reviewNotes: 'ulang' })).rejects.toBeInstanceOf(ConflictException);
  });

  it('misa yang belum selesai tidak dapat diulas walau status pelayanan induk sudah DONE (override Admin)', async () => {
    const { umat, orderId } = await doneOrder();
    const belum = await fx.item(orderId, 'PENDING');
    const jalan = await fx.item(orderId, 'IN_PROGRESS');
    for (const itemId of [belum, jalan]) {
      await expect(reviews.submitReview(String(orderId), { userId: umat.id, itemId, rating: 5, reviewNotes: 'terlalu cepat' })).rejects.toThrow(/setelah pelayanan selesai atau ditutup/);
      expect((await fx.row('order_items', itemId)).rating).toBeNull();
    }
    const ditutup = await fx.item(orderId, 'CLOSE');
    await reviews.submitReview(String(orderId), { userId: umat.id, itemId: ditutup, rating: 3, reviewNotes: 'misa ditutup tetap dapat diulas' });
    expect((await fx.row('order_items', ditutup)).rating).toBe(3);
  });
});
