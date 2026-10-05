import { Body, Controller, Get, Post, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiResponse, ApiTags } from '@nestjs/swagger';
import { IsIn, IsInt, IsOptional, IsString, MaxLength, Min } from 'class-validator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { Roles } from '../../common/decorators/roles.decorator';
import { AccessService, AuthUser } from '../../common/access/access.service';
import { APPROVER_ROLES } from '../../common/access/role-groups';
import { ApproveUserDto, ApproveUserResponseDto } from '../../auth.dto';
import { AuthService } from './auth.service';
import { ApprovalPolicyService } from './approval-policy.service';

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
    if (this.access.isAdmin(user)) return await this.authService.getPengurusPendingUmat(lingkunganId, keuskupanId, pengurusUserId);
    const scope = await this.policy.scopeFor(user.sub);
    if (scope?.kind === 'LINGKUNGAN') return await this.authService.getPengurusPendingUmat(String(scope.lingkunganId));
    if (scope?.kind === 'KEUSKUPAN') return await this.authService.getPengurusPendingUmat(undefined, String(scope.keuskupanId));
    return [];
  }

  @Post('pengurus/process-approval')
  @Roles(...APPROVER_ROLES)
  @ApiOperation({ summary: 'Proses Persetujuan Umat / Pengurus oleh penyetuju yang berwenang' })
  async processPengurusApproval(@CurrentUser() user: AuthUser, @Body() body: ProcessApprovalDto) {
    await this.policy.authorize(user.sub, body.targetUserId, body.action);
    const result = await this.authService.processPengurusApproval({ ...body, approverUserId: user.sub });
    this.policy.afterProcessed(body.targetUserId);
    return result;
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
    await this.policy.authorize(user.sub, Number(dto.targetUserId), dto.action === 'APPROVED' ? 'APPROVE' : 'REJECT');
    const result = await this.authService.approveRegistration(dto);
    this.policy.afterProcessed(Number(dto.targetUserId));
    return result;
  }
}
