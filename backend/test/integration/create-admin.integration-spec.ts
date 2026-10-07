import { Pool } from 'pg';
import * as bcrypt from 'bcrypt';
import { createAdmin, validateAdminInput } from '../../src/database/create-admin';
import { TEST_DATABASE_URL, connect, describeDb, disconnect } from './db-fixture';

describeDb('Skrip pembuatan akun admin (PostgreSQL sungguhan)', () => {
  let pool: Pool;
  const phone = `62898${String(Date.now()).slice(-8)}`;
  const base = { phone, password: 'Sandi-Uji-12345', name: 'Admin Uji Skrip', role: 'ADMIN' };

  beforeAll(async () => {
    await connect();
    pool = new Pool({ connectionString: TEST_DATABASE_URL, max: 2 });
  });
  afterAll(async () => {
    try {
      const u = await pool.query('SELECT id FROM auth_users WHERE phone_number = $1', [phone]);
      for (const r of u.rows) {
        await pool.query('DELETE FROM user_profiles WHERE user_id = $1', [r.id]);
        await pool.query('DELETE FROM auth_users WHERE id = $1', [r.id]);
      }
    } finally {
      await pool.end();
      await disconnect();
    }
  });

  it('isian tidak sah ditolak sebelum menyentuh basis data', () => {
    expect(validateAdminInput({ ...base, phone: '0812345' })).toMatch(/ADMIN_PHONE/);
    expect(validateAdminInput({ ...base, role: 'UMAT' })).toMatch(/ADMIN_ROLE/);
    expect(validateAdminInput({ ...base, name: 'ab' })).toMatch(/ADMIN_NAME/);
    expect(validateAdminInput({ ...base, password: 'pendek1' })).toMatch(/minimal 12/);
    expect(validateAdminInput({ ...base, password: 'hurufsajahurufsaja' })).toMatch(/huruf dan angka/);
    expect(validateAdminInput(base)).toBeNull();
  });

  it('membuat akun aktif dengan password ter-hash, peran dan profil yang benar', async () => {
    expect(await createAdmin(pool, base)).toBe('DIBUAT');
    const row = (await pool.query(`SELECT u.password_hash, u.account_status, u.is_active, r.code, p.full_name FROM auth_users u JOIN roles r ON r.id = u.role_id JOIN user_profiles p ON p.user_id = u.id WHERE u.phone_number = $1`, [phone])).rows[0];
    expect(row.code).toBe('ADMIN');
    expect(row.account_status).toBe('APPROVED');
    expect(row.is_active).toBe(true);
    expect(row.full_name).toBe('Admin Uji Skrip');
    expect(row.password_hash).not.toContain(base.password);
    expect(await bcrypt.compare(base.password, row.password_hash)).toBe(true);
  });

  it('akun yang sudah ada tidak ditimpa tanpa izin eksplisit; reset mengganti password dan peran', async () => {
    await expect(createAdmin(pool, { ...base, password: 'Sandi-Lain-98765' })).rejects.toThrow(/sudah ada/);
    const stillOld = (await pool.query('SELECT password_hash FROM auth_users WHERE phone_number = $1', [phone])).rows[0].password_hash;
    expect(await bcrypt.compare(base.password, stillOld)).toBe(true);

    expect(await createAdmin(pool, { ...base, password: 'Sandi-Lain-98765', role: 'SUPERADMIN', resetPassword: true })).toBe('PASSWORD_DIRESET');
    const row = (await pool.query(`SELECT u.password_hash, r.code FROM auth_users u JOIN roles r ON r.id = u.role_id WHERE u.phone_number = $1`, [phone])).rows[0];
    expect(row.code).toBe('SUPERADMIN');
    expect(await bcrypt.compare('Sandi-Lain-98765', row.password_hash)).toBe(true);
    expect(await bcrypt.compare(base.password, row.password_hash)).toBe(false);
  });
});
