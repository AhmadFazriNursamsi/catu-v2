import { ConflictException, ForbiddenException, NotFoundException, BadRequestException } from '@nestjs/common';
import * as bcrypt from 'bcrypt';
import { DataSource } from 'typeorm';
import { AccountStatusService } from '../../src/common/access/account-status.service';
import { AccountDeletionService, DELETED_USER_NAME, deletedPhoneNumber } from '../../src/modules/account/account-deletion.service';
import { Fixture, connect, describeDb, disconnect } from './db-fixture';

const PASSWORD = 'Rahasia123';

describeDb('Hapus akun sendiri (PostgreSQL sungguhan)', () => {
  let ds: DataSource;
  let fx: Fixture;
  let svc: AccountDeletionService;
  let accounts: AccountStatusService;
  let t: Awaited<ReturnType<Fixture['territory']>>;

  beforeAll(async () => {
    ds = await connect();
    fx = new Fixture(ds);
    accounts = new AccountStatusService(ds);
    svc = new AccountDeletionService(ds, accounts);
    t = await fx.territory();
  });
  afterAll(async () => {
    try {
      await fx.cleanup();
    } finally {
      await disconnect();
    }
  });

  async function userWithPassword(role: string) {
    const u = await fx.user(role, { parokiId: t.paroki1 });
    await ds.query('UPDATE auth_users SET password_hash = $1 WHERE id = $2', [await bcrypt.hash(PASSWORD, 4), u.id]);
    await ds.query(`UPDATE user_profiles SET email = 'a@b.c', address = 'Jl. Uji 1', birth_date = '2000-01-01' WHERE user_id = $1`, [u.id]);
    return u;
  }

  it('menganonimkan data pribadi, membebaskan nomor HP, memutus sesi; riwayat pelayanan dan pesan tetap ada', async () => {
    const umat = await userWithPassword('UMAT');
    const [{ phone_number: phone }] = await ds.query('SELECT phone_number FROM auth_users WHERE id = $1', [umat.id]);
    const orderId = await fx.order({ userId: umat.id, parokiId: t.paroki1, status: 'DONE', scheduledDate: '2026-01-01' });
    const groupId = await fx.chatGroup(orderId);
    await ds.query(`INSERT INTO chat_group_members (chat_group_id, user_id, role_in_group) VALUES ($1, $2, 'MEMBER')`, [groupId, umat.id]);
    await ds.query(`INSERT INTO chat_messages (chat_group_id, sender_id, message) VALUES ($1, $2, 'Terima kasih Romo')`, [groupId, umat.id]);
    await ds.query(`INSERT INTO user_devices (user_id, fcm_token) VALUES ($1, $2)`, [umat.id, `tok-${fx.tag}`]);
    expect((await accounts.get(umat.id))?.isActive).toBe(true);

    await expect(svc.deleteOwnAccount(umat.id, PASSWORD)).resolves.toMatchObject({ success: true });

    const [u] = await ds.query('SELECT phone_number, is_active, deleted_at, password_hash FROM auth_users WHERE id = $1', [umat.id]);
    expect(u.phone_number).toBe(deletedPhoneNumber(umat.id));
    expect(u.is_active).toBe(false);
    expect(u.deleted_at).not.toBeNull();
    expect(await bcrypt.compare(PASSWORD, u.password_hash).catch(() => false)).toBe(false);
    const [p] = await ds.query('SELECT full_name, email, address, birth_date FROM user_profiles WHERE user_id = $1', [umat.id]);
    expect(p).toEqual({ full_name: DELETED_USER_NAME, email: null, address: null, birth_date: null });
    // Token lama langsung tidak berlaku (guard membaca is_active), tanpa menunggu cache.
    expect((await accounts.get(umat.id))?.isActive).toBe(false);
    // Nomor asli bebas: tidak ada akun lain yang memakainya.
    expect(await ds.query('SELECT 1 FROM auth_users WHERE phone_number = $1', [phone])).toHaveLength(0);
    expect(await ds.query('SELECT 1 FROM user_devices WHERE user_id = $1', [umat.id])).toHaveLength(0);
    expect(await ds.query('SELECT 1 FROM chat_group_members WHERE user_id = $1', [umat.id])).toHaveLength(0);
    expect(await ds.query('SELECT 1 FROM chat_messages WHERE sender_id = $1', [umat.id])).toHaveLength(1);
    expect((await fx.row('orders', orderId)).status_text).toBe('DONE');

    await expect(svc.deleteOwnAccount(umat.id, PASSWORD)).rejects.toBeInstanceOf(NotFoundException);
    // Tidak bisa dihidupkan kembali, mis. oleh persetujuan atau ganti status admin.
    await expect(ds.query(`UPDATE auth_users SET account_status = 'APPROVED', is_active = true WHERE id = $1`, [umat.id])).rejects.toThrow(/sudah dihapus/);
    await expect(ds.query(`UPDATE auth_users SET updated_at = now() WHERE id = $1`, [umat.id])).resolves.toBeDefined();
    const [{ account_status }] = await ds.query('SELECT account_status::text FROM auth_users WHERE id = $1', [umat.id]);
    expect(account_status).toBe('REJECTED');
  });

  it('kata sandi salah ditolak dan tidak mengubah apa pun', async () => {
    const umat = await userWithPassword('UMAT');
    await expect(svc.deleteOwnAccount(umat.id, 'salah')).rejects.toBeInstanceOf(BadRequestException);
    const [u] = await ds.query('SELECT is_active, deleted_at FROM auth_users WHERE id = $1', [umat.id]);
    expect(u).toEqual({ is_active: true, deleted_at: null });
  });

  it('ditolak selama Umat masih punya pelayanan berjalan', async () => {
    const umat = await userWithPassword('UMAT');
    await fx.order({ userId: umat.id, parokiId: t.paroki1, status: 'CONFIRMED' });
    await expect(svc.deleteOwnAccount(umat.id, PASSWORD)).rejects.toBeInstanceOf(ConflictException);
  });

  it('ditolak selama Romo masih melayani; undangan yang belum dijawab dianggap ditolak saat akun dihapus', async () => {
    const umat = await fx.user('UMAT', { parokiId: t.paroki1 });
    const romo = await userWithPassword('ROMO_PAROKI');
    const active = await fx.order({ userId: umat.id, parokiId: t.paroki1, status: 'CONFIRMED' });
    await ds.query('UPDATE orders SET accepted_romo_id = $1 WHERE id = $2', [romo.id, active]);
    await expect(svc.deleteOwnAccount(romo.id, PASSWORD)).rejects.toBeInstanceOf(ConflictException);

    await ds.query(`UPDATE orders SET status = 'DONE' WHERE id = $1`, [active]);
    const multi = await fx.order({ userId: umat.id, parokiId: t.paroki1, status: 'CONFIRMED' });
    const misa = await fx.item(multi, 'CONFIRMED', 5, romo.id);
    await expect(svc.deleteOwnAccount(romo.id, PASSWORD)).rejects.toBeInstanceOf(ConflictException);
    await ds.query(`UPDATE order_items SET status = 'DONE' WHERE id = $1`, [misa]);
    await ds.query(`UPDATE orders SET status = 'DONE' WHERE id = $1`, [multi]);
    const invited = await fx.order({ userId: umat.id, parokiId: t.paroki1, status: 'PENDING' });
    await ds.query(`INSERT INTO order_assignments (order_id, romo_id, status) VALUES ($1, $2, 'WAITING')`, [invited, romo.id]);
    await svc.deleteOwnAccount(romo.id, PASSWORD);
    const [a] = await ds.query('SELECT status::text AS status FROM order_assignments WHERE order_id = $1 AND romo_id = $2', [invited, romo.id]);
    expect(a.status).toBe('DECLINED');
  });

  it('akun admin tidak dapat dihapus dari aplikasi', async () => {
    const admin = await userWithPassword('ADMIN');
    await expect(svc.deleteOwnAccount(admin.id, PASSWORD)).rejects.toBeInstanceOf(ForbiddenException);
  });
});
