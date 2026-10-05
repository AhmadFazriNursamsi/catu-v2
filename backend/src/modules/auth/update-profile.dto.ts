import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsIn, IsOptional } from 'class-validator';
import { UpdateUserProfileDto } from '../../orders.dto';

/** Perubahan profil sendiri: field dasar ditambah jenis kelamin. */
export class UpdateProfileDto extends UpdateUserProfileDto {
  @ApiPropertyOptional({ example: 'L', description: 'Jenis kelamin: L (laki-laki) atau P (perempuan)' })
  @IsOptional()
  @IsIn(['L', 'P'])
  gender?: 'L' | 'P';
}
