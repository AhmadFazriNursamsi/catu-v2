import { HttpException, HttpStatus, Injectable } from '@nestjs/common';
import { InjectDataSource } from '@nestjs/typeorm';
import { createHmac, randomInt, timingSafeEqual } from 'node:crypto';
import { DataSource } from 'typeorm';

export const OTP_TTL_MS = 5 * 60 * 1000;
export const OTP_MAX_ATTEMPTS = 5;
export const OTP_RESEND_COOLDOWN_MS = 60 * 1000;
export const OTP_MAX_PER_HOUR = 5;

export type OtpCheck = 'OK' | 'INVALID' | 'EXPIRED' | 'TOO_MANY_ATTEMPTS';

@Injectable()
export class OtpService {
  constructor(@InjectDataSource() private readonly dataSource: DataSource) {}

  private hash(phone: string, purpose: string, code: string): string {
    const key = process.env.OTP_SECRET || process.env.JWT_SECRET;
    if (!key) throw new Error('OTP_SECRET / JWT_SECRET belum dikonfigurasi.');
    return createHmac('sha256', key).update(`${purpose}:${phone}:${code}`).digest('hex');
  }

  async issue(phone: string, purpose: string): Promise<{ code: string; expiresAt: Date }> {
    const recent = await this.dataSource.query(
      `SELECT created_at FROM otp_codes WHERE phone_number = $1 AND purpose = $2 AND created_at > now() - interval '1 hour'
       ORDER BY created_at DESC`,
      [phone, purpose],
    );
    if (recent.length > 0) {
      const waitMs = new Date(recent[0].created_at).getTime() + OTP_RESEND_COOLDOWN_MS - Date.now();
      if (waitMs > 0) {
        throw new HttpException(`Tunggu ${Math.ceil(waitMs / 1000)} detik sebelum meminta kode baru.`, HttpStatus.TOO_MANY_REQUESTS);
      }
    }
    if (recent.length >= OTP_MAX_PER_HOUR) {
      throw new HttpException('Terlalu banyak permintaan kode. Coba lagi dalam 1 jam.', HttpStatus.TOO_MANY_REQUESTS);
    }
    const code = randomInt(0, 1_000_000).toString().padStart(6, '0');
    const expiresAt = new Date(Date.now() + OTP_TTL_MS);
    await this.dataSource.transaction(async (m) => {
      await m.query(`UPDATE otp_codes SET consumed_at = now() WHERE phone_number = $1 AND purpose = $2 AND consumed_at IS NULL`, [phone, purpose]);
      await m.query(`INSERT INTO otp_codes (phone_number, purpose, code_hash, expires_at) VALUES ($1, $2, $3, $4)`, [phone, purpose, this.hash(phone, purpose, code), expiresAt]);
    });
    return { code, expiresAt };
  }

  async check(phone: string, purpose: string, code: string, opts: { consume?: boolean } = {}): Promise<OtpCheck> {
    const rows = await this.dataSource.query(
      `SELECT id, code_hash, attempts, expires_at, verified_at FROM otp_codes
       WHERE phone_number = $1 AND purpose = $2 AND consumed_at IS NULL
       ORDER BY created_at DESC LIMIT 1`,
      [phone, purpose],
    );
    const row = rows[0];
    if (!row || new Date(row.expires_at).getTime() <= Date.now()) return 'EXPIRED';
    if (Number(row.attempts) >= OTP_MAX_ATTEMPTS) return 'TOO_MANY_ATTEMPTS';
    const given = Buffer.from(this.hash(phone, purpose, String(code ?? '').trim()));
    const stored = Buffer.from(String(row.code_hash));
    if (given.length !== stored.length || !timingSafeEqual(given, stored)) {
      await this.dataSource.query(`UPDATE otp_codes SET attempts = attempts + 1 WHERE id = $1`, [row.id]);
      return Number(row.attempts) + 1 >= OTP_MAX_ATTEMPTS ? 'TOO_MANY_ATTEMPTS' : 'INVALID';
    }
    if (opts.consume) {
      if (!row.verified_at) return 'INVALID';
      const [, changed] = await this.dataSource.query(`UPDATE otp_codes SET consumed_at = now() WHERE id = $1 AND consumed_at IS NULL`, [row.id]);
      return Number(changed) > 0 ? 'OK' : 'EXPIRED';
    }
    await this.dataSource.query(`UPDATE otp_codes SET verified_at = COALESCE(verified_at, now()) WHERE id = $1`, [row.id]);
    return 'OK';
  }

  async revoke(phone: string, purpose: string): Promise<void> {
    await this.dataSource.query(`UPDATE otp_codes SET consumed_at = now() WHERE phone_number = $1 AND purpose = $2 AND consumed_at IS NULL`, [phone, purpose]);
  }

  async purgeOld(): Promise<void> {
    await this.dataSource.query(`DELETE FROM otp_codes WHERE created_at < now() - interval '1 day'`);
  }
}
