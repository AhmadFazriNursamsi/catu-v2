import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsIn, IsOptional, Matches } from 'class-validator';
import { UpdateUserProfileDto } from '../../orders.dto';

const DMY = /^\d{2}\/\d{2}\/\d{4}$/;

/** Perubahan profil: field dasar ditambah jenis kelamin dan tanggal masa jabatan. */
export class UpdateProfileDto extends UpdateUserProfileDto {
  @ApiPropertyOptional({ example: 'L', description: 'Jenis kelamin: L (laki-laki) atau P (perempuan)' })
  @IsOptional()
  @IsIn(['L', 'P'])
  gender?: 'L' | 'P';

  @ApiPropertyOptional({ example: '01/01/2024', description: 'Tanggal Mulai Jabatan (dd/mm/yyyy); null menghapus' })
  @IsOptional()
  @Matches(DMY, { message: 'Tanggal mulai jabatan harus berformat dd/mm/yyyy' })
  jabatanStartDate?: string | null;

  @ApiPropertyOptional({ example: '31/12/2027', description: 'Tanggal Selesai Jabatan (dd/mm/yyyy); null menghapus' })
  @IsOptional()
  @Matches(DMY, { message: 'Tanggal selesai jabatan harus berformat dd/mm/yyyy' })
  jabatanEndDate?: string | null;
}
