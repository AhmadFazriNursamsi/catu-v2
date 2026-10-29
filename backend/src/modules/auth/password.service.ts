import {
  Injectable,
  BadRequestException,
  NotFoundException,
} from '@nestjs/common';
import { InjectDataSource } from '@nestjs/typeorm';
import { DataSource } from 'typeorm';
import * as bcrypt from 'bcrypt';
import { ChangePasswordDto } from '../../auth.dto';
import { AccountStatusService } from '../../common/access/account-status.service';
import { LoginLinkService } from '../login-link/login-link.service';

@Injectable()
export class PasswordService {
  constructor(
    @InjectDataSource() private readonly dataSource: DataSource,
    private readonly accounts: AccountStatusService,
    private readonly loginLinks: LoginLinkService,
  ) {}

  /** `viaLoginLink`: sesi dari tautan WhatsApp; boleh tanpa kata sandi lama selama kata sandi masih sementara. */
  async changePassword(dto: ChangePasswordDto, opts: { viaLoginLink?: boolean } = {}) {
    if (!dto.newPassword || dto.newPassword.trim().length < 6) {
      throw new BadRequestException('Kata sandi baru minimal 6 karakter.');
    }

    const user = await this.findUser(dto);
    if (!user) {
      throw new NotFoundException('Pengguna tidak ditemukan.');
    }

    if (!(opts.viaLoginLink && user.must_change_password === true)) {
      if (!dto.currentPassword) {
        throw new BadRequestException('Kata sandi saat ini wajib diisi.');
      }
      const isPasswordValid = await bcrypt.compare(
        dto.currentPassword,
        user.password_hash || '',
      );
      if (!isPasswordValid) {
        throw new BadRequestException('Kata sandi saat ini (lama) tidak sesuai.');
      }
    }

    const isSamePassword = await bcrypt.compare(
      dto.newPassword,
      user.password_hash || '',
    );
    if (isSamePassword) {
      throw new BadRequestException('Kata sandi baru tidak boleh sama dengan kata sandi lama.');
    }

    const newHash = await bcrypt.hash(dto.newPassword.trim(), 10);

    await this.dataSource.query(
      `UPDATE auth_users
       SET password_hash = $1, must_change_password = FALSE, updated_at = CURRENT_TIMESTAMP
       WHERE id = $2`,
      [newHash, user.id],
    );
    this.accounts.invalidate(Number(user.id));
    await this.loginLinks.invalidateForUser(Number(user.id));

    return {
      statusCode: 200,
      message: 'Kata sandi berhasil diperbarui.',
    };
  }

  private async findUser(dto: ChangePasswordDto) {
    if (dto.userId != null) {
      const userIdNum = typeof dto.userId === 'string' ? parseInt(dto.userId, 10) : Number(dto.userId);
      if (!isNaN(userIdNum)) {
        const users = await this.dataSource.query(
          `SELECT id, phone_number, password_hash, must_change_password FROM auth_users WHERE id = $1`,
          [userIdNum],
        );
        if (users.length > 0) return users[0];
      }
    }

    if (dto.phoneNumber) {
      let phone = dto.phoneNumber.trim();
      if (phone.startsWith('0')) phone = phone.substring(1);
      if (phone.startsWith('62')) phone = phone.substring(2);
      const fullPhone = `62${phone}`;

      const users = await this.dataSource.query(
        `SELECT id, phone_number, password_hash, must_change_password FROM auth_users WHERE phone_number = $1 OR phone_number = $2 OR phone_number = $3`,
        [fullPhone, `0${phone}`, dto.phoneNumber.trim()],
      );
      if (users.length > 0) return users[0];
    }

    return null;
  }
}
