import { HttpException, HttpStatus, Injectable, Logger } from '@nestjs/common';
import { InjectDataSource } from '@nestjs/typeorm';
import * as bcrypt from 'bcrypt';
import { DataSource } from 'typeorm';
import { RequestResetOtpDto, ResetPasswordDto, VerifyResetOtpDto } from '../../auth.dto';
import { WhatsappService } from '../whatsapp/whatsapp.service';
import { OTP_TTL_MS, OtpCheck, OtpService } from './otp.service';

const PURPOSE = 'RESET_PASSWORD';

const OTP_MESSAGES: Record<Exclude<OtpCheck, 'OK'>, string> = {
  INVALID: 'Kode OTP salah.',
  EXPIRED: 'Kode OTP sudah kedaluwarsa. Silakan minta kode baru.',
  TOO_MANY_ATTEMPTS: 'Terlalu banyak percobaan kode salah. Silakan minta kode baru.',
};

function canonicalPhone(raw: string): string {
  let d = String(raw ?? '').replace(/\D/g, '');
  if (d.startsWith('0')) d = d.substring(1);
  if (d.startsWith('62')) d = d.substring(2);
  return `62${d}`;
}

@Injectable()
export class PasswordResetService {
  private readonly logger = new Logger(PasswordResetService.name);

  constructor(
    @InjectDataSource() private readonly dataSource: DataSource,
    private readonly otp: OtpService,
    private readonly wa: WhatsappService,
  ) {}

  private async findUser(raw: string) {
    const phone = canonicalPhone(raw);
    const local = phone.substring(2);
    const users = await this.dataSource.query(
      `SELECT u.id, u.phone_number, p.full_name FROM auth_users u LEFT JOIN user_profiles p ON p.user_id = u.id
       WHERE u.phone_number = $1 OR u.phone_number = $2 OR u.phone_number = $3`,
      [phone, `0${local}`, String(raw ?? '').trim()],
    );
    return { phone, user: users[0] };
  }

  async requestOtp(dto: RequestResetOtpDto) {
    const { phone, user } = await this.findUser(dto.phoneNumber);
    if (!user) return { statusCode: 404, message: 'Nomor WhatsApp tidak terdaftar di sistem CATU.' };

    const devMode = !this.wa.enabled && process.env.NODE_ENV !== 'production';
    if (!this.wa.enabled && !devMode) {
      throw new HttpException('Layanan WhatsApp belum aktif. Hubungi admin CATU.', HttpStatus.SERVICE_UNAVAILABLE);
    }

    const { code } = await this.otp.issue(phone, PURPOSE);
    const minutes = Math.round(OTP_TTL_MS / 60000);
    const text =
      `*CATU* - Kode verifikasi atur ulang kata sandi Anda: *${code}*\n\n` +
      `Berlaku ${minutes} menit. Jangan berikan kode ini kepada siapa pun, termasuk yang mengaku petugas CATU.`;
    if (!devMode) {
      const sent = await this.wa.send(phone, text, { priority: 'otp', key: `otp:${PURPOSE}:${phone}:${code}` });
      if (!sent.ok) {
        this.logger.warn(`OTP ke ${phone.slice(0, 5)}*** gagal diantrekan: ${sent.code}`);
        await this.otp.revoke(phone, PURPOSE);
        throw new HttpException(sent.message || 'Kode OTP gagal dikirim. Coba lagi nanti.', HttpStatus.SERVICE_UNAVAILABLE);
      }
    } else {
      this.logger.warn('WhatsApp tidak dikonfigurasi: kode OTP dikembalikan di respons (hanya di luar production).');
    }

    return {
      statusCode: 200,
      message: 'Kode OTP verifikasi sedang dikirim ke WhatsApp Anda.',
      phoneNumber: user.phone_number,
      fullName: user.full_name || 'Pengguna',
      maskedPhone: phone.replace(/(\d{4})\d+(\d{3})/, '$1-****-$2'),
      ...(devMode ? { demoOtp: code } : {}),
    };
  }

  async verifyOtp(dto: VerifyResetOtpDto) {
    const result = await this.otp.check(canonicalPhone(dto.phoneNumber), PURPOSE, dto.otpCode);
    if (result !== 'OK') return { statusCode: 400, message: OTP_MESSAGES[result] };
    return { statusCode: 200, message: 'Verifikasi kode OTP berhasil.', verified: true };
  }

  async resetPassword(dto: ResetPasswordDto) {
    if (!dto.newPassword || dto.newPassword.length < 6) return { statusCode: 400, message: 'Kata sandi baru minimal 6 karakter.' };
    const { phone, user } = await this.findUser(dto.phoneNumber);
    if (!user) return { statusCode: 404, message: 'Pengguna tidak ditemukan.' };
    const result = await this.otp.check(phone, PURPOSE, dto.otpCode, { consume: true });
    if (result !== 'OK') return { statusCode: 400, message: OTP_MESSAGES[result] };
    const newHash = await bcrypt.hash(dto.newPassword, 10);
    await this.dataSource.query(`UPDATE auth_users SET password_hash = $1, updated_at = CURRENT_TIMESTAMP WHERE id = $2`, [newHash, user.id]);
    return { statusCode: 200, message: 'Kata sandi berhasil diperbarui! Silakan masuk dengan kata sandi baru Anda.' };
  }
}
