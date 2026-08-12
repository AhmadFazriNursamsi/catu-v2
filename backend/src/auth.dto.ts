import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsEnum, IsNotEmpty, IsOptional, IsString, MinLength } from 'class-validator';

export enum RoleCodeEnum {
  UMAT = 'UMAT',
  ROMO_PAROKI = 'ROMO_PAROKI',
  ROMO_ORDO = 'ROMO_ORDO',
  PENGURUS_LINGKUNGAN = 'PENGURUS_LINGKUNGAN',
  KOORDINATOR_KEUSKUPAN = 'KOORDINATOR_KEUSKUPAN',
}

export enum PengurusPositionEnum {
  KETUA = 'KETUA',
  WAKIL = 'WAKIL',
  SEKRETARIS = 'SEKRETARIS',
}

export enum RomoPositionEnum {
  KETUA_ROMO = 'KETUA_ROMO',
  ROMO_BIASA = 'ROMO_BIASA',
}

export class RegisterUserDto {
  @ApiProperty({ example: 'Budi Raharjo', description: 'Nama lengkap pendaftar' })
  @IsString()
  @IsNotEmpty()
  fullName: string;

  @ApiProperty({ example: '6281234567890', description: 'Nomor WhatsApp / HP aktif' })
  @IsString()
  @IsNotEmpty()
  phoneNumber: string;

  @ApiPropertyOptional({ example: 'budi@example.com', description: 'Email opsional' })
  @IsString()
  @IsOptional()
  email?: string;

  @ApiProperty({ example: 'password123', description: 'Password akun min 6 karakter' })
  @IsString()
  @MinLength(6)
  password: string;

  @ApiProperty({ enum: RoleCodeEnum, example: RoleCodeEnum.UMAT, description: 'Role akun' })
  @IsEnum(RoleCodeEnum)
  roleCode: RoleCodeEnum;

  @ApiPropertyOptional({ example: 1, description: 'ID Keuskupan (Wajib untuk Umat, Romo, Pengurus, Koordinator)' })
  @IsOptional()
  keuskupanId?: number;

  @ApiPropertyOptional({ example: 10, description: 'ID Paroki (Wajib untuk Umat, Romo Paroki)' })
  @IsOptional()
  parokiId?: number;

  @ApiPropertyOptional({ example: 101, description: 'ID Wilayah (Wajib untuk Umat, Pengurus Lingkungan)' })
  @IsOptional()
  wilayahId?: number;

  @ApiPropertyOptional({ example: 1001, description: 'ID Lingkungan (Wajib untuk Umat, Pengurus Lingkungan)' })
  @IsOptional()
  lingkunganId?: number;

  @ApiPropertyOptional({ example: 3175, description: 'ID Kabupaten/Kota (Wajib untuk Romo Ordo)' })
  @IsOptional()
  kabupatenKotaId?: number;

  @ApiPropertyOptional({ enum: PengurusPositionEnum, description: 'Jabatan Pengurus (KETUA, WAKIL, SEKRETARIS)' })
  @IsEnum(PengurusPositionEnum)
  @IsOptional()
  pengurusPosition?: PengurusPositionEnum;

  @ApiPropertyOptional({ enum: RomoPositionEnum, description: 'Jabatan Romo (KETUA_ROMO, ROMO_BIASA)' })
  @IsEnum(RomoPositionEnum)
  @IsOptional()
  romoPosition?: RomoPositionEnum;

  @ApiPropertyOptional({ example: 2024, description: 'Tahun Mulai Masa Jabatan (untuk Ketua Romo Paroki, Ketua Romo Ordo, Ketua/Wakil/Sekretaris Lingkungan)' })
  @IsOptional()
  jabatanStartYear?: number;

  @ApiPropertyOptional({ example: 2027, description: 'Tahun Selesai Masa Jabatan' })
  @IsOptional()
  jabatanEndYear?: number;

  @ApiPropertyOptional({ example: true, description: 'Flag Jabatan Aktif/Tidak' })
  @IsOptional()
  isJabatanActive?: boolean;
}

export class LoginDto {
  @ApiProperty({ example: '6281234567890', description: 'Nomor HP terdaftar' })
  @IsString()
  @IsNotEmpty()
  phoneNumber: string;

  @ApiProperty({ example: 'password123', description: 'Password akun' })
  @IsString()
  @IsNotEmpty()
  password: string;
}

export class ApproveUserDto {
  @ApiProperty({ example: 10, description: 'ID User pendaftar yang akan di-approve' })
  targetUserId: number;

  @ApiProperty({ example: 'APPROVED', enum: ['APPROVED', 'REJECTED'] })
  action: 'APPROVED' | 'REJECTED';

  @ApiPropertyOptional({ example: 'Data domisili telah terverifikasi', description: 'Catatan / Alasan keputusan' })
  rejectionReason?: string;
}

// ==============================================================================
// RESPONSE SCHEMAS UNTUK SWAGGER DOCUMENTATION (FULLY TYPED RESPONSES)
// ==============================================================================

export class UserProfileResponseDto {
  @ApiProperty({ example: 1 })
  id: number;

  @ApiProperty({ example: 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11' })
  uuid: string;

  @ApiProperty({ example: 'Budi Raharjo' })
  fullName: string;

  @ApiProperty({ example: '6281234567890' })
  phoneNumber: string;

  @ApiProperty({ example: 'budi@example.com' })
  email: string;

  @ApiProperty({ example: 'UMAT' })
  roleCode: string;

  @ApiProperty({ example: 'APPROVED', enum: ['PENDING_APPROVAL', 'APPROVED', 'REJECTED'] })
  accountStatus: string;

  @ApiPropertyOptional({ example: 'Keuskupan Agung Jakarta' })
  keuskupanName?: string;

  @ApiPropertyOptional({ example: 'Paroki Santo Antonius Padua - Otista' })
  parokiName?: string;

  @ApiPropertyOptional({ example: 'Wilayah St. Agustinus' })
  wilayahName?: string;

  @ApiPropertyOptional({ example: 'Lingkungan St. Agnes 1' })
  lingkunganName?: string;

  @ApiPropertyOptional({ example: 'JAKARTA TIMUR' })
  kabupatenKotaName?: string;

  @ApiPropertyOptional({ example: 'KETUA', enum: ['KETUA', 'WAKIL', 'SEKRETARIS'] })
  pengurusPosition?: string;

  @ApiPropertyOptional({ example: 'KETUA_ROMO', enum: ['KETUA_ROMO', 'ROMO_BIASA'] })
  romoPosition?: string;

  @ApiPropertyOptional({ example: 2024 })
  jabatanStartYear?: number;

  @ApiPropertyOptional({ example: 2027 })
  jabatanEndYear?: number;

  @ApiPropertyOptional({ example: true })
  isJabatanActive?: boolean;
}

export class RegisterResponseDto {
  @ApiProperty({ example: 201 })
  statusCode: number;

  @ApiProperty({ example: 'Registrasi berhasil! Akun Anda sedang menunggu persetujuan (APPROVAL) dari Pengurus Lingkungan.' })
  message: string;

  @ApiProperty({ type: UserProfileResponseDto })
  user: UserProfileResponseDto;

  @ApiProperty({ example: 'Ketua Lingkungan Agus (6283333333333)', description: 'Pihak yang bertanggung jawab menyetujui pendaftaran' })
  approvalAssignedTo: string;
}

export class LoginResponseDto {
  @ApiProperty({ example: 200 })
  statusCode: number;

  @ApiProperty({ example: 'Login Berhasil' })
  message: string;

  @ApiProperty({ example: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxIiwibmFtZSI6IkJ1ZGkgUmFoYXJqbyIsInJvbGUiOiJVTUFUIiwiaWF0IjoxNzg2NDI5NTQwfQ.jwt_signature' })
  accessToken: string;

  @ApiProperty({ type: UserProfileResponseDto })
  user: UserProfileResponseDto;
}

export class ApproveUserResponseDto {
  @ApiProperty({ example: 200 })
  statusCode: number;

  @ApiProperty({ example: 'Akun user Budi Raharjo (ID: 10) telah berhasil di-APPROVED' })
  message: string;

  @ApiProperty({ example: 10 })
  targetUserId: number;

  @ApiProperty({ example: 'APPROVED' })
  status: string;

  @ApiProperty({ example: 'Admin Super / Ketua Lingkungan' })
  approvedBy: string;

  @ApiProperty({ example: '2026-08-11T13:32:00.000Z' })
  approvedAt: string;
}
