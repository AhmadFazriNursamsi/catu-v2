import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsArray, IsBoolean, IsDateString, IsEnum, IsInt, IsNotEmpty, IsNumber, IsOptional, IsString, ValidateNested } from 'class-validator';
import { Type } from 'class-transformer';

export class CreateOrderItemDto {
  @ApiProperty({ example: 'Misa Penutupan Peti', description: 'Nama item misa kedukaan' })
  @IsString()
  @IsNotEmpty()
  itemName: string;

  @ApiProperty({ example: '2026-08-15', description: 'Tanggal misa' })
  @IsDateString()
  scheduledDate: string;

  @ApiProperty({ example: '18:00', description: 'Jam mulai misa' })
  @IsString()
  scheduledTimeStart: string;

  @ApiProperty({ example: '19:30', description: 'Jam selesai misa' })
  @IsString()
  scheduledTimeEnd: string;

  @ApiProperty({ example: 'Rumah Duka Carolus Room 101', description: 'Lokasi misa' })
  @IsString()
  locationName: string;
}

export class CreateOrderDto {
  @ApiPropertyOptional({ example: 1, description: 'ID User yang membuat order' })
  @IsNumber()
  @IsInt()
  @IsOptional()
  userId?: number;

  @ApiProperty({ example: 1, description: 'ID Kategori Pelayanan (1: Perminyakan, 2: Misa Kedukaan, dll)' })
  @IsNumber()
  @IsInt()
  serviceCategoryId: number;

  @ApiProperty({ example: 3, description: 'ID Tingkat Urgensi (1: Biasa, 2: Penting, 3: Darurat/Kritis)' })
  @IsNumber()
  @IsInt()
  urgencyLevelId: number;

  @ApiProperty({ example: '2026-08-15', description: 'Tanggal utama pelayanan' })
  @IsDateString()
  scheduledDate: string;

  @ApiProperty({ example: '18:00', description: 'Jam utama pelayanan' })
  @IsString()
  scheduledTime: string;

  @ApiProperty({ example: 'Rumah Sakit Columbia Kamar 302', description: 'Nama lokasi' })
  @IsString()
  @IsNotEmpty()
  locationName: string;

  @ApiPropertyOptional({ example: 'Jl. Ahmad Yani No. 45, Jakarta', description: 'Alamat detail' })
  @IsString()
  @IsNotEmpty()
  addressDetail: string;

  @ApiPropertyOptional({ example: 1, description: 'ID Keuskupan (jika beda paroki)' })
  @IsNumber()
  @IsInt()
  @IsOptional()
  keuskupanId?: number;

  @ApiPropertyOptional({ example: 10, description: 'ID Paroki (jika beda paroki)' })
  @IsNumber()
  @IsInt()
  @IsOptional()
  parokiId?: number;

  @ApiPropertyOptional({ example: 101, description: 'ID Wilayah' })
  @IsNumber()
  @IsInt()
  @IsOptional()
  wilayahId?: number;

  @ApiPropertyOptional({ example: 1001, description: 'ID Lingkungan' })
  @IsNumber()
  @IsInt()
  @IsOptional()
  lingkunganId?: number;

  @ApiPropertyOptional({ example: 3175, description: 'ID Kabupaten/Kota' })
  @IsNumber()
  @IsInt()
  @IsOptional()
  kabupatenKotaId?: number;

  @ApiPropertyOptional({ example: 'Mohon membawa peralatan minyak suci', description: 'Catatan tambahan' })
  @IsString()
  @IsOptional()
  notes?: string;

  @ApiPropertyOptional({ example: 'https://example.com/foto_duka.jpg', description: 'URL atau path foto duka almarhum / banner kedukaan' })
  @IsString()
  @IsOptional()
  attachmentUrl?: string;

  @ApiPropertyOptional({
    type: [CreateOrderItemDto],
    description: 'Daftar item Misa Kedukaan (Wajib diisi jika kategori = Misa Kedukaan)',
  })
  @IsArray()
  @IsOptional()
  @ValidateNested({ each: true })
  @Type(() => CreateOrderItemDto)
  items?: CreateOrderItemDto[];
}

export class RespondOrderAssignmentDto {
  @ApiProperty({ 
    example: 'CONFIRMED', 
    enum: ['CONFIRMED', 'IN_PROGRESS', 'DONE', 'CLOSE', 'FAIL', 'DECLINED', 'ACCEPTED'], 
    description: 'Status pelayanan: CONFIRMED (terima), IN_PROGRESS (berlangsung), DONE (selesai), CLOSE (ditutup), FAIL (gagal), DECLINED (tolak)' 
  })
  @IsEnum(['CONFIRMED', 'IN_PROGRESS', 'DONE', 'CLOSE', 'FAIL', 'DECLINED', 'ACCEPTED'])
  status: 'CONFIRMED' | 'IN_PROGRESS' | 'DONE' | 'CLOSE' | 'FAIL' | 'DECLINED' | 'ACCEPTED';

  @ApiPropertyOptional({ example: 2, description: 'ID Romo yang memproses pelayanan' })
  @IsNumber()
  @IsOptional()
  romoId?: number;

  @ApiPropertyOptional({ example: 10, description: 'ID sub-item Misa specific yang diterima' })
  @IsNumber()
  @IsOptional()
  itemId?: number;

  @ApiPropertyOptional({ example: 'Ada bentrok jadwal misa paroki', description: 'Alasan penolakan dari Romo' })
  @IsString()
  @IsOptional()
  declineReason?: string;
}

export class UpdateUserProfileDto {
  @ApiPropertyOptional({ example: 'Kevin Antaratama', description: 'Nama lengkap' })
  @IsOptional()
  @IsString()
  fullName?: string;

  @ApiPropertyOptional({ example: '081234567890', description: 'Nomor Handphone' })
  @IsOptional()
  @IsString()
  phoneNumber?: string;

  @ApiPropertyOptional({ example: 'kevin@catu.id', description: 'Email' })
  @IsOptional()
  @IsString()
  email?: string;

  @ApiPropertyOptional({ example: '01/01/1990', description: 'Tanggal Lahir' })
  @IsOptional()
  @IsString()
  birthDate?: string;

  @ApiPropertyOptional({ example: 'Jl. Sutera Utama No. 18', description: 'Alamat' })
  @IsOptional()
  @IsString()
  address?: string;

  @ApiPropertyOptional({ example: 'https://example.com/avatar.jpg', description: 'URL Foto Profil' })
  @IsOptional()
  @IsString()
  avatarUrl?: string;

  @ApiPropertyOptional({ example: 'ROMO_ORDO', description: 'Role Code (UMAT, ROMO_PAROKI, ROMO_ORDO, PENGURUS_LINGKUNGAN)' })
  @IsOptional()
  @IsString()
  roleCode?: string;

  @ApiPropertyOptional({ example: 2, description: 'ID Ordo / Kongregasi' })
  @IsOptional()
  @IsNumber()
  ordoId?: number;

  @ApiPropertyOptional({ example: 1, description: 'ID Keuskupan' })
  @IsOptional()
  keuskupanId?: number;

  @ApiPropertyOptional({ example: 1, description: 'ID Paroki' })
  @IsOptional()
  parokiId?: number;

  @ApiPropertyOptional({ example: 1, description: 'ID Wilayah' })
  @IsOptional()
  wilayahId?: number;

  @ApiPropertyOptional({ example: 1, description: 'ID Lingkungan' })
  @IsOptional()
  lingkunganId?: number;

  @ApiPropertyOptional({ example: 1, description: 'ID Provinsi' })
  @IsOptional()
  provinsiId?: number;

  @ApiPropertyOptional({ example: 3175, description: 'ID Kabupaten/Kota' })
  @IsOptional()
  kabupatenKotaId?: number;

  @ApiPropertyOptional({ example: 'APPROVED', description: 'Status Akun' })
  @IsOptional()
  @IsString()
  accountStatus?: string;

  @ApiPropertyOptional({ example: 'Ketua Lingkungan', description: 'Jabatan Pengurus Lingkungan' })
  @IsOptional()
  @IsString()
  pengurusPosition?: string;

  @ApiPropertyOptional({ example: 'Pastor Kepala Paroki', description: 'Posisi Pastoral Romo Paroki' })
  @IsOptional()
  @IsString()
  romoPosition?: string;

  @ApiPropertyOptional({ example: 2024, description: 'Tahun Mulai Jabatan' })
  @IsOptional()
  jabatanStartYear?: number;

  @ApiPropertyOptional({ example: 2027, description: 'Tahun Selesai Jabatan' })
  @IsOptional()
  jabatanEndYear?: number;

  @ApiPropertyOptional({ example: true, description: 'Apakah jabatan masih aktif' })
  @IsOptional()
  isJabatanActive?: boolean;

  @ApiPropertyOptional({ example: true, description: 'Kirim notifikasi ke Ketua Lingkungan' })
  @IsOptional()
  notifyKetuaLingkungan?: boolean;
}

export class SendChatMessageDto {
  @ApiPropertyOptional({ example: 1, description: 'ID user pengirim pesan' })
  @IsOptional()
  senderId?: number;

  @ApiProperty({ example: 'TEXT', enum: ['TEXT', 'IMAGE', 'DOCUMENT', 'LOCATION'], description: 'Tipe pesan' })
  @IsEnum(['TEXT', 'IMAGE', 'DOCUMENT', 'LOCATION'])
  messageType: 'TEXT' | 'IMAGE' | 'DOCUMENT' | 'LOCATION';

  @ApiProperty({ example: 'Selamat sore Romo, kami menunggu kedatangannya.', description: 'Isi pesan chat' })
  @IsString()
  @IsNotEmpty()
  message: string;

  @ApiPropertyOptional({ example: 'https://s3.amazonaws.com/catu/surat_kedukaan.pdf', description: 'Link attachment URL' })
  @IsString()
  @IsOptional()
  attachmentUrl?: string;
}

// ══════════════════════════════════════════════════════════════════════════
// MASTER DATA CRUD DTOs
// ══════════════════════════════════════════════════════════════════════════

export class CreateKeuskupanDto {
  @ApiProperty({ example: 'Keuskupan Agung Semarang' })
  @IsString()
  @IsNotEmpty()
  name: string;

  @ApiPropertyOptional({ example: 'KAS' })
  @IsString()
  @IsOptional()
  code?: string;
}

export class UpdateKeuskupanDto {
  @ApiPropertyOptional({ example: 'Keuskupan Agung Semarang' })
  @IsString()
  @IsOptional()
  name?: string;

  @ApiPropertyOptional({ example: 'KAS' })
  @IsString()
  @IsOptional()
  code?: string;
}

export class CreateParokiDto {
  @ApiProperty({ example: 1 })
  @IsNumber()
  keuskupanId: number;

  @ApiProperty({ example: 'Paroki Santa Maria Regina' })
  @IsString()
  @IsNotEmpty()
  name: string;

  @ApiPropertyOptional({ example: 'Bintaro Jaya Sektor 7' })
  @IsString()
  @IsOptional()
  address?: string;
}

export class UpdateParokiDto {
  @ApiPropertyOptional({ example: 1 })
  @IsNumber()
  @IsOptional()
  keuskupanId?: number;

  @ApiPropertyOptional({ example: 'Paroki Santa Maria Regina' })
  @IsString()
  @IsOptional()
  name?: string;

  @ApiPropertyOptional({ example: 'Bintaro Jaya Sektor 7' })
  @IsString()
  @IsOptional()
  address?: string;
}

export class CreateWilayahDto {
  @ApiProperty({ example: 10 })
  @IsNumber()
  parokiId: number;

  @ApiProperty({ example: 'Wilayah St. Ignatius' })
  @IsString()
  @IsNotEmpty()
  name: string;
}

export class UpdateWilayahDto {
  @ApiPropertyOptional({ example: 10 })
  @IsNumber()
  @IsOptional()
  parokiId?: number;

  @ApiPropertyOptional({ example: 'Wilayah St. Ignatius' })
  @IsString()
  @IsOptional()
  name?: string;
}

export class CreateLingkunganDto {
  @ApiProperty({ example: 101 })
  @IsNumber()
  wilayahId: number;

  @ApiProperty({ example: 'Lingkungan St. Gabriel 1' })
  @IsString()
  @IsNotEmpty()
  name: string;
}

export class UpdateLingkunganDto {
  @ApiPropertyOptional({ example: 101 })
  @IsNumber()
  @IsOptional()
  wilayahId?: number;

  @ApiPropertyOptional({ example: 'Lingkungan St. Gabriel 1' })
  @IsString()
  @IsOptional()
  name?: string;
}

export class CreateOrdoDto {
  @ApiProperty({ example: 'Ordo Fratrum Minorum' })
  @IsString()
  @IsNotEmpty()
  name: string;

  @ApiPropertyOptional({ example: 'OFM' })
  @IsString()
  @IsOptional()
  code?: string;

  @ApiPropertyOptional({ example: 'Kramat Raya, Jakarta Pusat' })
  @IsString()
  @IsOptional()
  address?: string;
}

export class UpdateOrdoDto {
  @ApiPropertyOptional({ example: 'Ordo Fratrum Minorum' })
  @IsString()
  @IsOptional()
  name?: string;

  @ApiPropertyOptional({ example: 'OFM' })
  @IsString()
  @IsOptional()
  code?: string;

  @ApiPropertyOptional({ example: 'Kramat Raya, Jakarta Pusat' })
  @IsString()
  @IsOptional()
  address?: string;
}

export class CreateServiceCategoryDto {
  @ApiProperty({ example: 'Misa Ulang Tahun Pernikahan' })
  @IsString()
  @IsNotEmpty()
  name: string;

  @ApiPropertyOptional({ example: 'Pelayanan misa syukur peringatan ulang tahun perkawinan' })
  @IsString()
  @IsOptional()
  description?: string;

  @ApiPropertyOptional({ example: false })
  @IsBoolean()
  @IsOptional()
  isUrgentByDefault?: boolean;

  @ApiPropertyOptional({ example: true })
  @IsBoolean()
  @IsOptional()
  isActive?: boolean;
}

export class UpdateServiceCategoryDto {
  @ApiPropertyOptional({ example: 'Misa Ulang Tahun Pernikahan' })
  @IsString()
  @IsOptional()
  name?: string;

  @ApiPropertyOptional({ example: 'Pelayanan misa syukur' })
  @IsString()
  @IsOptional()
  description?: string;

  @ApiPropertyOptional({ example: false })
  @IsBoolean()
  @IsOptional()
  isUrgentByDefault?: boolean;

  @ApiPropertyOptional({ example: true })
  @IsBoolean()
  @IsOptional()
  isActive?: boolean;
}

export class CreateRoleDto {
  @ApiProperty({ example: 'PETUGAS_LITURGI' })
  @IsString()
  @IsNotEmpty()
  code: string;

  @ApiProperty({ example: 'Petugas Liturgi' })
  @IsString()
  @IsNotEmpty()
  name: string;
}

export class UpdateRoleDto {
  @ApiPropertyOptional({ example: 'PETUGAS_LITURGI' })
  @IsString()
  @IsOptional()
  code?: string;

  @ApiPropertyOptional({ example: 'Petugas Liturgi' })
  @IsString()
  @IsOptional()
  name?: string;
}

export class CreatePositionDto {
  @ApiProperty({ example: 'PENGURUS_LINGKUNGAN', enum: ['PENGURUS_LINGKUNGAN', 'ROMO_PAROKI', 'ROMO_ORDO'] })
  @IsString()
  @IsNotEmpty()
  category: string;

  @ApiProperty({ example: 'KETUA_LINGKUNGAN' })
  @IsString()
  @IsNotEmpty()
  code: string;

  @ApiProperty({ example: 'Ketua Lingkungan' })
  @IsString()
  @IsNotEmpty()
  name: string;

  @ApiPropertyOptional({ example: true })
  @IsBoolean()
  @IsOptional()
  isLead?: boolean;
}

export class UpdatePositionDto {
  @ApiPropertyOptional({ example: 'PENGURUS_LINGKUNGAN', enum: ['PENGURUS_LINGKUNGAN', 'ROMO_PAROKI', 'ROMO_ORDO'] })
  @IsString()
  @IsOptional()
  category?: string;

  @ApiPropertyOptional({ example: 'KETUA_LINGKUNGAN' })
  @IsString()
  @IsOptional()
  code?: string;

  @ApiPropertyOptional({ example: 'Ketua Lingkungan' })
  @IsString()
  @IsOptional()
  name?: string;

  @ApiPropertyOptional({ example: true })
  @IsBoolean()
  @IsOptional()
  isLead?: boolean;
}


