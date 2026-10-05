import { ConflictException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { InjectDataSource } from '@nestjs/typeorm';
import { DataSource } from 'typeorm';
import { AccountStatusService } from '../../common/access/account-status.service';
import { ApprovalAccount, ApprovalAction, ApprovalScope, approvalScope, decideApproval, isKoordinator, isLeaderRomo } from './approval-policy';

/** Memuat akun penyetuju dan target dari database, lalu menegakkan kebijakan persetujuan (approval-policy.ts). */
@Injectable()
export class ApprovalPolicyService {
  constructor(
    @InjectDataSource() private readonly dataSource: DataSource,
    private readonly accounts: AccountStatusService,
  ) {}

  async load(userId: number): Promise<ApprovalAccount | null> {
    const rows = await this.dataSource.query(
      `SELECT u.id, r.code AS role_code, u.account_status, u.approval_assigned_to_user_id,
              p.pengurus_position, p.romo_position, p.is_jabatan_active,
              p.keuskupan_id, p.lingkungan_id, p.paroki_id, p.ordo_id
       FROM auth_users u JOIN roles r ON r.id = u.role_id LEFT JOIN user_profiles p ON p.user_id = u.id
       WHERE u.id = $1`,
      [userId],
    );
    if (rows.length === 0) return null;
    const n = (v: any) => (v == null ? null : Number(v));
    const r = rows[0];
    return {
      id: Number(r.id),
      roleCode: r.role_code,
      status: r.account_status,
      pengurusPosition: r.pengurus_position,
      romoPosition: r.romo_position,
      isJabatanActive: r.is_jabatan_active,
      keuskupanId: n(r.keuskupan_id),
      lingkunganId: n(r.lingkungan_id),
      parokiId: n(r.paroki_id),
      ordoId: n(r.ordo_id),
      assignedApproverId: n(r.approval_assigned_to_user_id),
    };
  }

  /** Melempar 404/403/409 bila [actorId] tidak boleh memproses [targetId]; kembalikan target bila boleh. */
  async authorize(actorId: number, targetId: number, action: ApprovalAction): Promise<ApprovalAccount> {
    const [actor, target] = await Promise.all([this.load(actorId), this.load(targetId)]);
    if (!target) throw new NotFoundException('Akun yang akan diproses tidak ditemukan.');
    if (!actor) throw new ForbiddenException('Akun penyetuju tidak ditemukan.');
    const decision = decideApproval(actor, target, action);
    if (!decision.allowed) {
      if (decision.status === 409) throw new ConflictException(decision.message);
      throw new ForbiddenException(decision.message);
    }
    if (action === 'APPROVE') await this.assertSingleLeader(target);
    return target;
  }

  async scopeFor(actorId: number): Promise<ApprovalScope | null> {
    const actor = await this.load(actorId);
    return actor ? approvalScope(actor) : null;
  }

  /** Setelah status berubah: cache status akun target dibuang agar berlaku seketika. */
  afterProcessed(targetId: number): void {
    this.accounts.invalidate(targetId);
  }

  /** Satu Kepala per paroki, satu Ketua per ordo, satu pemegang tiap jabatan per lingkungan. */
  private async assertSingleLeader(t: ApprovalAccount): Promise<void> {
    const taken = async (sql: string, params: any[], label: string) => {
      const rows = await this.dataSource.query(sql, params);
      if (rows.length > 0) throw new ConflictException(`${label} sudah terisi dan aktif oleh ${rows[0].full_name}. Tidak boleh ada jabatan ganda.`);
    };
    if (t.roleCode === 'ROMO_PAROKI' && t.parokiId && isLeaderRomo(t)) {
      await taken(
        `SELECT p.full_name FROM user_profiles p JOIN auth_users u ON u.id = p.user_id JOIN roles r ON r.id = u.role_id
         WHERE r.code = 'ROMO_PAROKI' AND p.paroki_id = $1 AND u.id <> $2 AND u.account_status = 'APPROVED'
           AND p.is_jabatan_active IS NOT FALSE AND UPPER(p.romo_position) ~ 'KETUA|KEPALA' LIMIT 1`,
        [t.parokiId, t.id],
        'Posisi Kepala Romo Paroki untuk paroki ini',
      );
    } else if (t.roleCode === 'ROMO_ORDO' && t.ordoId && isLeaderRomo(t)) {
      await taken(
        `SELECT p.full_name FROM user_profiles p JOIN auth_users u ON u.id = p.user_id JOIN roles r ON r.id = u.role_id
         WHERE r.code = 'ROMO_ORDO' AND p.ordo_id = $1 AND u.id <> $2 AND u.account_status = 'APPROVED'
           AND p.is_jabatan_active IS NOT FALSE AND UPPER(p.romo_position) ~ 'KETUA|KEPALA|SUPERIOR' LIMIT 1`,
        [t.ordoId, t.id],
        'Posisi Ketua Romo Ordo untuk ordo ini',
      );
    } else if (t.roleCode === 'PENGURUS_LINGKUNGAN' && t.lingkunganId && t.pengurusPosition && !isKoordinator(t)) {
      await taken(
        `SELECT p.full_name FROM user_profiles p JOIN auth_users u ON u.id = p.user_id
         WHERE p.lingkungan_id = $1 AND u.id <> $2 AND u.account_status = 'APPROVED'
           AND LOWER(p.pengurus_position) = LOWER($3) LIMIT 1`,
        [t.lingkunganId, t.id, t.pengurusPosition],
        `Jabatan ${t.pengurusPosition} untuk lingkungan ini`,
      );
    }
  }
}
