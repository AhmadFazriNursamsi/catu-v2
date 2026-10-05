import { Injectable } from '@nestjs/common';
import { InjectDataSource } from '@nestjs/typeorm';
import { DataSource } from 'typeorm';

export const ACCOUNT_APPROVED = 'APPROVED';

export interface AccountState {
  status: string;
  roleCode: string;
  isActive: boolean;
}

const CACHE_TTL_MS = 5_000;

/**
 * Status dan peran akun yang berlaku SAAT INI (bukan saat token diterbitkan). Dipakai JwtAuthGuard agar akun yang
 * belum disetujui / ditolak / dinonaktifkan tidak dapat memakai API, dan agar perubahan peran langsung berlaku.
 * Hasil di-cache singkat supaya tidak menambah query pada setiap request; persetujuan berlaku dalam hitungan detik.
 */
@Injectable()
export class AccountStatusService {
  private readonly cache = new Map<number, { at: number; state: AccountState | null }>();

  constructor(@InjectDataSource() private readonly dataSource: DataSource) {}

  async get(userId: number): Promise<AccountState | null> {
    const hit = this.cache.get(userId);
    if (hit && Date.now() - hit.at < CACHE_TTL_MS) return hit.state;
    const rows = await this.dataSource.query(
      `SELECT u.account_status, u.is_active, r.code AS role_code
       FROM auth_users u JOIN roles r ON r.id = u.role_id WHERE u.id = $1`,
      [userId],
    );
    const state: AccountState | null = rows.length === 0 ? null : { status: rows[0].account_status, roleCode: rows[0].role_code, isActive: rows[0].is_active !== false };
    this.cache.set(userId, { at: Date.now(), state });
    return state;
  }

  /** Dipanggil setelah status/peran akun berubah agar berlaku seketika. */
  invalidate(userId: number): void {
    this.cache.delete(userId);
  }
}
