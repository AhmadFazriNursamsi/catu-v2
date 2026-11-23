import { Controller, Get, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { BackupsService } from './backups.service';

@ApiTags('Cadangan Data')
@ApiBearerAuth('JWT-auth')
@Controller('backups')
@UseGuards(JwtAuthGuard, RolesGuard)
export class BackupsController {
  constructor(private readonly backups: BackupsService) {}

  @Get('status')
  @Roles('SUPERADMIN')
  @ApiOperation({ summary: 'Status cadangan database (harian, deploy, salinan cloud) — Super Admin saja, tanpa isi berkas' })
  status() {
    return this.backups.status();
  }
}
