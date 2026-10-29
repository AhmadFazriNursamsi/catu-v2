import { createHash, randomBytes } from 'node:crypto';
import { Injectable, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { InjectDataSource } from '@nestjs/typeorm';
import { DataSource } from 'typeorm';

/** Masa berlaku tautan; sengaja pendek karena tautan = akses penuh ke akun sampai kata sandi diganti. */
export const LOGIN_LINK_TTL_HOURS = 48;
/** Klaim `via` pada JWT hasil tautan: mengizinkan ganti kata sandi tanpa kata sandi lama (hanya selama masih sementara). */
export const LOGIN_LINK_VIA = 'login-link';
export const LOGIN_LINK_TOKEN_PATTERN = /^[A-Za-z0-9_-]{20,128}$/;

type Db = { query: (sql: string, params?: unknown[]) => Promise<any> };

const hashToken = (token: string) => createHash('sha256').update(token).digest('hex');

@Injectable()
export class LoginLinkService {
  constructor(
    @InjectDataSource() private readonly dataSource: DataSource,
    private readonly jwt: JwtService,
  ) {}

  /** Membuat token baru untuk user; `db` boleh query runner agar ikut transaksi pendaftaran. */
  async create(userId: number, db: Db = this.dataSource): Promise<string> {
    const token = randomBytes(32).toString('base64url');
    await db.query(`DELETE FROM auth_login_links WHERE expires_at < now() - interval '30 days'`);
    await db.query(
      `INSERT INTO auth_login_links (user_id, token_hash, expires_at)
       VALUES ($1, $2, now() + make_interval(hours => $3))`,
      [userId, hashToken(token), LOGIN_LINK_TTL_HOURS],
    );
    return token;
  }

  /** Alamat tautan untuk pesan WhatsApp; null bila PUBLIC_APP_URL belum diisi (pesan lalu hanya berisi kata sandi). */
  buildUrl(token: string): string | null {
    const base = (process.env.PUBLIC_APP_URL || '').trim().replace(/\/+$/, '');
    return base ? `${base}/api/public/m/login?t=${token}` : null;
  }

  /** Mematikan semua tautan aktif milik user (dipanggil saat kata sandi diganti). */
  async invalidateForUser(userId: number): Promise<void> {
    await this.dataSource.query(
      `UPDATE auth_login_links SET used_at = now() WHERE user_id = $1 AND used_at IS NULL`,
      [userId],
    );
  }

  /** Menukar token dengan sesi. Token langsung hangus (atomik), bahkan bila validasi berikutnya gagal. */
  async consume(token: string) {
    const invalid = new UnauthorizedException(
      'Tautan masuk sudah dipakai atau kedaluwarsa. Masuk dengan nomor HP dan kata sandi sementara dari WhatsApp.',
    );
    if (!LOGIN_LINK_TOKEN_PATTERN.test(token ?? '')) throw invalid;

    const result = await this.dataSource.query(
      `UPDATE auth_login_links SET used_at = now()
       WHERE token_hash = $1 AND used_at IS NULL AND expires_at > now()
       RETURNING user_id`,
      [hashToken(token)],
    );
    // TypeORM (postgres) mengembalikan [baris, jumlah] untuk UPDATE ... RETURNING.
    const claimed: Array<{ user_id: number }> = Array.isArray(result[0]) ? result[0] : result;
    if (!claimed.length) throw invalid;

    const rows = await this.dataSource.query(
      `SELECT u.id, u.uuid, u.phone_number, u.account_status, u.must_change_password, r.code AS role_code,
              p.full_name, p.email, p.keuskupan_id, p.paroki_id, p.wilayah_id, p.lingkungan_id, p.ordo_id
       FROM auth_users u
       JOIN roles r ON r.id = u.role_id
       LEFT JOIN user_profiles p ON p.user_id = u.id
       WHERE u.id = $1`,
      [claimed[0].user_id],
    );
    const user = rows[0];
    // Tautan hanya berlaku selama kata sandi sementara belum diganti dan bukan untuk akun administrator.
    if (!user || user.must_change_password !== true || ['ADMIN', 'SUPERADMIN'].includes(user.role_code)) throw invalid;
    if (user.account_status !== 'APPROVED') throw invalid;

    const accessToken = this.jwt.sign({
      sub: user.id,
      uuid: user.uuid,
      phoneNumber: user.phone_number,
      roleCode: user.role_code,
      fullName: user.full_name,
      via: LOGIN_LINK_VIA,
    });
    return {
      statusCode: 200,
      message: 'Login Berhasil',
      accessToken,
      user: {
        id: user.id,
        uuid: user.uuid,
        fullName: user.full_name,
        phoneNumber: user.phone_number,
        email: user.email,
        roleCode: user.role_code,
        accountStatus: user.account_status,
        mustChangePassword: true,
        loginViaLink: true,
        keuskupanId: user.keuskupan_id,
        parokiId: user.paroki_id,
        wilayahId: user.wilayah_id,
        lingkunganId: user.lingkungan_id,
        ordoId: user.ordo_id,
      },
    };
  }
}
