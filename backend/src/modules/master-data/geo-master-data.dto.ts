import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsNotEmpty, IsNumber, IsOptional, IsString, IsIn } from 'class-validator';

export class CreateProvinsiDto {
  @ApiProperty({ example: 'JAWA BARAT' })
  @IsString()
  @IsNotEmpty()
  name: string;
}

export class UpdateProvinsiDto {
  @ApiPropertyOptional({ example: 'JAWA BARAT' })
  @IsString()
  @IsOptional()
  name?: string;
}

export class CreateKabupatenKotaDto {
  @ApiProperty({ example: 1 })
  @IsNumber()
  @IsNotEmpty()
  provinsiId: number;

  @ApiProperty({ example: 'KOTA BANDUNG' })
  @IsString()
  @IsNotEmpty()
  name: string;

  @ApiPropertyOptional({ example: 'KOTA', enum: ['KOTA', 'KABUPATEN'] })
  @IsString()
  @IsOptional()
  @IsIn(['KOTA', 'KABUPATEN'])
  type?: string;
}

export class UpdateKabupatenKotaDto {
  @ApiPropertyOptional({ example: 1 })
  @IsNumber()
  @IsOptional()
  provinsiId?: number;

  @ApiPropertyOptional({ example: 'KOTA BANDUNG' })
  @IsString()
  @IsOptional()
  name?: string;

  @ApiPropertyOptional({ example: 'KOTA', enum: ['KOTA', 'KABUPATEN'] })
  @IsString()
  @IsOptional()
  @IsIn(['KOTA', 'KABUPATEN'])
  type?: string;
}
