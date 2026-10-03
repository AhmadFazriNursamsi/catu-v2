import {
  Controller,
  Post,
  Put,
  Body,
  Get,
  Param,
  Query,
  HttpCode,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { Throttle } from '@nestjs/throttler';
import { Public } from '../../common/decorators/public.decorator';
import { Roles } from '../../common/decorators/roles.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { AccessService, AuthUser } from '../../common/access/access.service';
import { ADMIN_ROLES, APPROVER_ROLES } from '../../common/access/role-groups';
import { signAccountToken } from '../../common/access/account-token';

// Batas ketat untuk endpoint rawan brute force (login, OTP, registrasi): 10 request/menit per IP.
const STRICT_LIMIT = { default: { limit: 10, ttl: 60000 } };
import {
  ApiTags,
  ApiOperation,
  ApiResponse,
  ApiBearerAuth,
} from '@nestjs/swagger';
import {
  RegisterUserDto,
  LoginDto,
  ApproveUserDto,
  RegisterResponseDto,
  LoginResponseDto,
  ApproveUserResponseDto,
  RequestResetOtpDto,
  VerifyResetOtpDto,
  ResetPasswordDto,
  ChangePasswordDto,
} from '../../auth.dto';
import { UpdateUserProfileDto } from '../../orders.dto';
import { AuthService } from './auth.service';
import { PasswordService } from './password.service';

@ApiTags('Auth & Registration')
@Controller('auth')
export class AuthController {
  constructor(
    private readonly authService: AuthService,
    private readonly passwordService: PasswordService,
    private readonly access: AccessService,
    private readonly jwtService: JwtService,
  ) {}

  @Public()
  @Get('roles')
  @ApiOperation({
    summary: 'Ambil Daftar Role Akun dari Database',
    description: 'Mengembalikan daftar 3 role utama: Umat, Romo Paroki, dan Romo Ordo.',
  })
  async getRoles() {
    return await this.authService.getRoles();
  }

  @Public()
  @Get('keuskupan')
  @ApiOperation({ summary: 'Ambil Daftar Keuskupan dari Database' })
  async getKeuskupan() {
    return await this.authService.getKeuskupan();
  }

  @Public()
  @Get('paroki')
  @ApiOperation({ summary: 'Ambil Daftar Paroki berdasarkan Keuskupan ID dari Database' })
  async getParoki(@Query('keuskupanId') keuskupanId?: string) {
    const kId = keuskupanId ? parseInt(keuskupanId, 10) : undefined;
    return await this.authService.getParoki(kId);
  }

  @Public()
  @Get('wilayah')
  @ApiOperation({ summary: 'Ambil Daftar Wilayah berdasarkan Paroki ID dari Database' })
  async getWilayah(@Query('parokiId') parokiId?: string) {
    const pId = parokiId ? parseInt(parokiId, 10) : undefined;
    return await this.authService.getWilayah(pId);
  }

  @Public()
  @Get('lingkungan')
  @ApiOperation({ summary: 'Ambil Daftar Lingkungan berdasarkan Wilayah ID dari Database' })
  async getLingkungan(@Query('wilayahId') wilayahId?: string) {
    const wId = wilayahId ? parseInt(wilayahId, 10) : undefined;
    return await this.authService.getLingkungan(wId);
  }

  @Public()
  @Get('provinsi')
  @ApiOperation({ summary: 'Ambil Daftar Provinsi dari Database' })
  async getProvinsi() {
    return await this.authService.getProvinsi();
  }

  @Public()
  @Get('kabupaten-kota')
  @ApiOperation({ summary: 'Ambil Daftar Kabupaten/Kota berdasarkan Provinsi ID dari Database' })
  async getKabupatenKota(@Query('provinsiId') provinsiId?: string) {
    const prId = provinsiId ? parseInt(provinsiId, 10) : undefined;
    return await this.authService.getKabupatenKota(prId);
  }

  @Public()
  @Get('ordo')
  @ApiOperation({ summary: 'Ambil Daftar Ordo / Kongregasi dari Database' })
  async getOrdo() {
    return await this.authService.getOrdo();
  }

  @Get('check-status')
  @ApiOperation({ summary: 'Cek Status Akun Terbaru Berdasarkan Nomor HP' })
  async checkAccountStatus(@CurrentUser() user: AuthUser, @Query('phone') phone: string) {
    const result: any = await this.authService.checkAccountStatus(phone);
    // Respons memuat profil lengkap: hanya pemilik akun (atau admin) yang boleh melihatnya.
    if (result?.user && !this.access.isAdmin(user)) this.access.assertSelf(user, result.user.id);
    return result;
  }

  @Get('pengurus/pending-umat')
  @Roles(...APPROVER_ROLES)
  @ApiOperation({ summary: 'Daftar Umat Baru yang Menunggu Persetujuan Pengurus Lingkungan / Koordinator Keuskupan' })
  async getPengurusPendingUmat(
    @CurrentUser() user: AuthUser,
    @Query('lingkunganId') lingkunganId?: string,
    @Query('keuskupanId') keuskupanId?: string,
    @Query('pengurusUserId') pengurusUserId?: string,
  ) {
    const actingUserId = this.access.isAdmin(user) ? pengurusUserId : String(user.sub);
    return await this.authService.getPengurusPendingUmat(lingkunganId, keuskupanId, actingUserId);
  }

  @Post('pengurus/process-approval')
  @Roles(...APPROVER_ROLES)
  @ApiOperation({ summary: 'Proses Persetujuan Umat oleh Pengurus Lingkungan' })
  async processPengurusApproval(
    @CurrentUser() user: AuthUser,
    @Body() body: { targetUserId: number; approverUserId: number; action: 'APPROVE' | 'REJECT'; rejectionReason?: string },
  ) {
    return await this.authService.processPengurusApproval({ ...body, approverUserId: user.sub });
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
    const actingUserId = this.access.isAdmin(user) ? romoUserId : String(user.sub);
    return await this.authService.getRomoPendingRomo(actingUserId, parokiId, ordoId);
  }

  @Post('romo/process-approval')
  @Roles(...APPROVER_ROLES)
  @ApiOperation({ summary: 'Proses Persetujuan Romo oleh Kepala Romo Paroki / Ketua Romo Ordo' })
  async processRomoApproval(
    @CurrentUser() user: AuthUser,
    @Body() body: { targetUserId: number; approverUserId: number; action: 'APPROVE' | 'REJECT'; rejectionReason?: string },
  ) {
    return await this.authService.processRomoApproval({ ...body, approverUserId: user.sub });
  }

  @Public()
  @Throttle(STRICT_LIMIT)
  @Post('register')
  @ApiOperation({
    summary: 'Registrasi User Baru (Terpisah Antara auth_users & user_profiles)',
    description:
      'Registrasi user baru. Kredensial login masuk ke auth_users, sedangkan biodata & domisili masuk ke user_profiles. Notifikasi approval dikirim berjenjang.',
  })
  @ApiResponse({ status: 201, description: 'Registrasi berhasil, akun berstatus PENDING_APPROVAL.', type: RegisterResponseDto })
  async register(@Body() dto: RegisterUserDto) {
    const result = await this.authService.register(dto);
    const accessToken = signAccountToken(this.jwtService, result.user);
    return { ...result, accessToken };
  }

  @Public()
  @Throttle(STRICT_LIMIT)
  @Post('login')
  @HttpCode(200)
  @ApiOperation({
    summary: 'Login User & Ambil Access Token',
    description: 'Login menggunakan nomor HP terdaftar (auth_users JOIN user_profiles). Nomor HP: 6281234567890, Password: password123',
  })
  @ApiResponse({ status: 200, description: 'Login berhasil, mengembalikan token JWT dan profil user lengkap.', type: LoginResponseDto })
  async login(@Body() dto: LoginDto) {
    return await this.authService.login(dto);
  }

  @Public()
  @Throttle(STRICT_LIMIT)
  @Post('admin/login')
  @HttpCode(200)
  @ApiOperation({
    summary: 'Login Khusus Administrator Web Portal',
    description: 'Hanya mengizinkan akun dengan peran ADMIN. User peran lain (UMAT, ROMO, PENGURUS) akan ditolak dengan status 403.',
  })
  async adminLogin(@Body() dto: LoginDto) {
    return await this.authService.adminLogin(dto);
  }

  @Public()
  @Throttle(STRICT_LIMIT)
  @Post('forgot-password/request-otp')
  @ApiOperation({
    summary: 'Request OTP untuk Lupa Kata Sandi (WhatsApp OTP)',
    description: 'Mengirimkan kode OTP verifikasi 6-digit ke nomor WhatsApp pengguna terdaftar.',
  })
  async requestResetOtp(@Body() dto: RequestResetOtpDto) {
    return await this.authService.requestResetOtp(dto);
  }

  @Public()
  @Throttle(STRICT_LIMIT)
  @Post('forgot-password/verify-otp')
  @ApiOperation({
    summary: 'Verifikasi Kode OTP Lupa Kata Sandi',
  })
  async verifyResetOtp(@Body() dto: VerifyResetOtpDto) {
    return await this.authService.verifyResetOtp(dto);
  }

  @Public()
  @Throttle(STRICT_LIMIT)
  @Post('forgot-password/reset')
  @ApiOperation({
    summary: 'Reset / Simpan Kata Sandi Baru',
  })
  async resetPassword(@Body() dto: ResetPasswordDto) {
    return await this.authService.resetPassword(dto);
  }

  @Post('change-password')
  @HttpCode(200)
  @ApiOperation({
    summary: 'Ubah Kata Sandi Pengguna yang Sudah Login',
    description: 'Memverifikasi kata sandi lama/saat ini, lalu memperbarui ke kata sandi baru (min 6 karakter).',
  })
  async changePassword(@CurrentUser() user: AuthUser, @Body() dto: ChangePasswordDto) {
    // Identitas selalu diambil dari token, bukan dari body.
    return await this.passwordService.changePassword({ ...dto, userId: user.sub, phoneNumber: undefined });
  }

  @Get('profile/:userId')
  @ApiBearerAuth('JWT-auth')
  @ApiOperation({ summary: 'Ambil Detail Profil User Lengkap dari Database' })
  async getProfile(@CurrentUser() user: AuthUser, @Param('userId') userIdParam: string) {
    // Umat hanya boleh melihat profilnya sendiri; peran pelayanan/pengurus/admin boleh melihat profil lain.
    if (this.access.isEndUser(user)) this.access.assertSelf(user, userIdParam);
    return await this.authService.getProfile(userIdParam);
  }

  @Put('profile/:userId')
  @ApiBearerAuth('JWT-auth')
  @ApiOperation({ summary: 'Ubah Data Profil User & Domisili Keumatan' })
  async updateProfile(
    @CurrentUser() user: AuthUser,
    @Param('userId') userIdParam: string,
    @Body() dto: UpdateUserProfileDto,
  ) {
    this.access.assertSelf(user, userIdParam);
    return await this.authService.updateProfile(userIdParam, dto);
  }

  @Post('approve-registration')
  @Roles(...APPROVER_ROLES)
  @ApiBearerAuth('JWT-auth')
  @ApiOperation({
    summary: 'Persetujuan Registrasi Pendaftaran User (Approval di auth_users)',
    description: 'Mengubah status pendaftaran user di auth_users dari PENDING_APPROVAL menjadi APPROVED atau REJECTED.',
  })
  @ApiResponse({ status: 200, description: 'Status persetujuan akun berhasil diperbarui.', type: ApproveUserResponseDto })
  async approveRegistration(@Body() dto: ApproveUserDto) {
    return await this.authService.approveRegistration(dto);
  }

  @Roles(...ADMIN_ROLES)
  @Get('admin/analytics')
  @ApiBearerAuth('JWT-auth')
  @ApiOperation({ summary: 'Ringkasan Metrik Dashboard Admin CATU' })
  async getAdminAnalytics() {
    return await this.authService.getAdminAnalytics();
  }

  @Roles(...ADMIN_ROLES)
  @Get('admin/users')
  @ApiBearerAuth('JWT-auth')
  @ApiOperation({ summary: 'Daftar Semua Pengguna untuk Manajemen Admin' })
  async getAdminUsers(
    @Query('role') role?: string,
    @Query('status') status?: string,
    @Query('search') search?: string,
  ) {
    return await this.authService.getAdminUsers(role, status, search);
  }

  @Roles(...ADMIN_ROLES)
  @Put('admin/users/:userId/status')
  @ApiBearerAuth('JWT-auth')
  @ApiOperation({ summary: 'Update Status Akun Pengguna oleh Admin' })
  async updateAdminUserStatus(
    @Param('userId') userIdParam: string,
    @Body() body: { status: string; isJabatanActive?: boolean },
  ) {
    return await this.authService.updateAdminUserStatus(userIdParam, body);
  }

  @Roles(...ADMIN_ROLES)
  @Put('admin/users/:userId/role')
  @ApiBearerAuth('JWT-auth')
  @ApiOperation({ summary: 'Update Role Pengguna oleh Admin' })
  async updateAdminUserRole(
    @Param('userId') userIdParam: string,
    @Body() body: { roleCode: string },
  ) {
    return await this.authService.updateAdminUserRole(userIdParam, body);
  }

  @Roles(...ADMIN_ROLES)
  @Put('admin/orders/:orderId/status')
  @ApiBearerAuth('JWT-auth')
  @ApiOperation({ summary: 'Update Status Pelayanan oleh Admin' })
  async updateAdminOrderStatus(
    @Param('orderId') orderIdParam: string,
    @Body() body: { status: string },
  ) {
    return await this.authService.updateAdminOrderStatus(orderIdParam, body);
  }

  @Roles(...ADMIN_ROLES)
  @Post('admin/logout')
  @HttpCode(200)
  @ApiOperation({ summary: 'Logout Admin dari Web Portal' })
  async adminLogout(@Body() _body: { userId?: number; fullName?: string }) {
    return { statusCode: 200, message: 'Admin berhasil logout' };
  }
}
