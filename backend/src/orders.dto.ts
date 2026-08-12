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

  @ApiProperty({ example: 'Jl. Ahmad Yani No. 45, Jakarta', description: 'Alamat detail' })
  @IsString()
  @IsNotEmpty()
  addressDetail: string;

  @ApiPropertyOptional({ example: 'Mohon membawa peralatan minyak suci', description: 'Catatan tambahan' })
  @IsString()
  @IsOptional()
  notes?: string;

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
  @ApiProperty({ example: 'ACCEPTED', enum: ['ACCEPTED', 'DECLINED'], description: 'Respon Romo terhadap tugas' })
  @IsEnum(['ACCEPTED', 'DECLINED'])
  status: 'ACCEPTED' | 'DECLINED';

  @ApiPropertyOptional({ example: 'Ada bentrok jadwal misa paroki', description: 'Alasan penolakan dari Romo' })
  @IsString()
  @IsOptional()
  declineReason?: string;
}

export class SendChatMessageDto {
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
