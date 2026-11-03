import { BadRequestException, Body, Controller, ForbiddenException, Get, Param, ParseIntPipe, Post, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiResponse, ApiTags } from '@nestjs/swagger';
import { IsIn, IsInt, IsOptional, IsString, MaxLength, Min } from 'class-validator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { Roles } from '../../common/decorators/roles.decorator';
import { AccessService, AuthUser } from '../../common/access/access.service';
import { APPROVER_ROLES } from '../../common/access/role-groups';
import { ApproveUserDto, ApproveUserResponseDto } from '../../auth.dto';
import { AuthService } from './auth.service';
import { ApprovalPolicyService } from './approval-policy.service';
import { RegionTransferService } from '../region-transfer/region-transfer.service';

export class ProcessApprovalDto {
  @IsInt()
  @Min(1)
  targetUserId: number;

  @IsIn(['APPROVE', 'REJECT'])
  action: 'APPROVE' | 'REJECT';

  /** Dikirim klien lama; diabaikan karena identitas penyetuju selalu diambil dari token. */
  @IsOptional()
  @IsInt()
  approverUserId?: number;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  rejectionReason?: string;
}

/** Penolakan wajib beralasan: pendaftar membacanya untuk memperbaiki data. */
function assertRejectionReason(action: string, reason?: string): void {
  if (/^REJECT/.test(action) && !(reason ?? '').trim()) throw new BadRequestException('Alasan penolakan wajib diisi.');
}

/**
 * Persetujuan pendaftaran akun. Setiap tindakan diperiksa terhadap kebijakan wewenang (approval-policy.ts):
 * penyetuju hanya dapat memproses akun di wilayah/jenjangnya dan tidak dapat memproses akunnya sendiri.
 * Daftar menunggu persetujuan dibatasi ke wilayah penyetuju; parameter wilayah dari klien hanya berlaku untuk Admin.
 */
@ApiTags('Persetujuan Akun')
@ApiBearerAuth('JWT-auth')
@Controller('auth')
export class ApprovalsController {
  constructor(
    private readonly authService: AuthService,
    private readonly policy: ApprovalPolicyService,
    private readonly access: AccessService,
    private readonly regionTransfer: RegionTransferService,
  ) {}

  @Get('pengurus/pending-umat')
  @Roles(...APPROVER_ROLES)
  @ApiOperation({ summary: 'Daftar Umat Baru yang Menunggu Persetujuan Pengurus Lingkungan / Koordinator Keuskupan' })
  async getPengurusPendingUmat(
    @CurrentUser() user: AuthUser,
    @Query('lingkunganId') lingkunganId?: string,
    @Query('keuskupanId') keuskupanId?: string,
    @Query('pengurusUserId') pengurusUserId?: string,
  ) {
    const scope = this.access.isAdmin(user) ? null : await this.policy.scopeFor(user.sub);
    if (!this.access.isAdmin(user) && scope?.kind !== 'LINGKUNGAN' && scope?.kind !== 'KEUSKUPAN') return [];
    const rows = this.access.isAdmin(user)
      ? await this.authService.getPengurusPendingUmat(lingkunganId, keuskupanId, pengurusUserId)
      : scope?.kind === 'LINGKUNGAN'
        ? await this.authService.getPengurusPendingUmat(String(scope.lingkunganId))
        : await this.authService.getPengurusPendingUmat(undefined, String((scope as any).keuskupanId));
    const isAdmin = this.access.isAdmin(user);
    const extra = await this.regionTransfer.pendingPengurus(isAdmin && lingkunganId ? Number(lingkunganId) : (scope as any)?.lingkunganId, isAdmin && keuskupanId ? Number(keuskupanId) : (scope as any)?.keuskupanId);
    const visible: any[] = [];
    for (const row of extra) {
      if (isAdmin || (await this.policy.authorize(user.sub, Number(row.id), 'REJECT').then(() => true, () => false))) visible.push(row);
    }
    return await this.regionTransfer.annotate([...rows, ...visible]);
  }

  @Post('pengurus/process-approval')
  @Roles(...APPROVER_ROLES)
  @ApiOperation({ summary: 'Proses Persetujuan Umat / Pengurus oleh penyetuju yang berwenang' })
  async processPengurusApproval(@CurrentUser() user: AuthUser, @Body() body: ProcessApprovalDto) {
    assertRejectionReason(body.action, body.rejectionReason);
    await this.policy.authorize(user.sub, body.targetUserId, body.action);
    const result = (await this.regionTransfer.resolve(body.targetUserId, user.sub, body.action, body.rejectionReason)) ?? (await this.authService.processPengurusApproval({ ...body, approverUserId: user.sub }));
    this.policy.afterProcessed(body.targetUserId);
    return result;
  }

  @Get('approvals/history')
  @Roles(...APPROVER_ROLES)
  @ApiOperation({ summary: 'Riwayat akun yang pernah disetujui / ditolak oleh penyetuju yang sedang login' })
  async getApprovalHistory(@CurrentUser() user: AuthUser) {
    await this.assertHistoryAllowed(user);
    return await this.policy.history(user.sub);
  }

  @Get('approvals/history/:id')
  @Roles(...APPROVER_ROLES)
  @ApiOperation({ summary: 'Detail lengkap satu entri riwayat persetujuan milik penyetuju yang sedang login' })
  async getApprovalHistoryDetail(@CurrentUser() user: AuthUser, @Param('id', ParseIntPipe) id: number) {
    await this.assertHistoryAllowed(user);
    return await this.policy.historyDetail(user.sub, id);
  }

  /** Riwayat persetujuan tidak tersedia bagi Koordinator Keuskupan. */
  private async assertHistoryAllowed(user: AuthUser): Promise<void> {
    if ((await this.policy.scopeFor(user.sub))?.kind === 'KEUSKUPAN') {
      throw new ForbiddenException('Riwayat persetujuan tidak tersedia bagi Koordinator.');
    }
  }

  @Get('romo/pending-romo')
  @Roles(...APPROVER_ROLES)
  @ApiOperation({ summary: 'Daftar Romo Baru yang Menunggu Persetujuan Kepala Romo Paroki / Ketua Romo Ordo' })
  async getRomoPendingRomo(
    @CurrentUser() user: AuthUser,
    @Query('romoUserId') romoUserId?: string,
    @Query('parokiId') parokiId?: string,
    @Query('ordoId') ordoId?: string,
  ) {
    if (this.access.isAdmin(user)) return await this.authService.getRomoPendingRomo(romoUserId, parokiId, ordoId);
    const scope = await this.policy.scopeFor(user.sub);
    if (scope?.kind === 'PAROKI') return await this.authService.getRomoPendingRomo(undefined, String(scope.parokiId));
    if (scope?.kind === 'ORDO') return await this.authService.getRomoPendingRomo(undefined, undefined, String(scope.ordoId));
    return [];
  }

  @Post('romo/process-approval')
  @Roles(...APPROVER_ROLES)
  @ApiOperation({ summary: 'Proses Persetujuan Romo oleh Kepala Romo Paroki / Ketua Romo Ordo' })
  async processRomoApproval(@CurrentUser() user: AuthUser, @Body() body: ProcessApprovalDto) {
    assertRejectionReason(body.action, body.rejectionReason);
    await this.policy.authorize(user.sub, body.targetUserId, body.action);
    const result = await this.authService.processRomoApproval({ ...body, approverUserId: user.sub });
    this.policy.afterProcessed(body.targetUserId);
    return result;
  }

  @Post('approve-registration')
  @Roles(...APPROVER_ROLES)
  @ApiOperation({
    summary: 'Persetujuan Registrasi Pendaftaran User (Approval di auth_users)',
    description: 'Mengubah status pendaftaran user di auth_users dari PENDING_APPROVAL menjadi APPROVED atau REJECTED.',
  })
  @ApiResponse({ status: 200, description: 'Status persetujuan akun berhasil diperbarui.', type: ApproveUserResponseDto })
  async approveRegistration(@CurrentUser() user: AuthUser, @Body() dto: ApproveUserDto) {
    assertRejectionReason(dto.action === 'APPROVED' ? 'APPROVE' : 'REJECT', (dto as any).rejectionReason);
    await this.policy.authorize(user.sub, Number(dto.targetUserId), dto.action === 'APPROVED' ? 'APPROVE' : 'REJECT');
    const result = (await this.regionTransfer.resolve(Number(dto.targetUserId), user.sub, dto.action === 'APPROVED' ? 'APPROVE' : 'REJECT', (dto as any).rejectionReason)) ?? (await this.authService.approveRegistration(dto));
    this.policy.afterProcessed(Number(dto.targetUserId));
    return result;
  }
}
