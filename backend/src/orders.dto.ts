import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsArray, IsDateString, IsEnum, IsInt, IsNotEmpty, IsNumber, IsOptional, IsString, ValidateNested } from 'class-validator';
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

  @ApiPropertyOptional({ example: 3175, description: 'ID Kabupaten/Kota' })
  @IsOptional()
  kabupatenKotaId?: number;

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
