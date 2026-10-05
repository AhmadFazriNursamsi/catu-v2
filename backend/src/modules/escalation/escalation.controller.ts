import { Body, Controller, Get, Put } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { IsInt, Max, Min } from 'class-validator';
import { Roles } from '../../common/decorators/roles.decorator';
import { ADMIN_ROLES } from '../../common/access/role-groups';
import { MAX_ESCALATION_MINUTES } from './escalation-rules';
import { EscalationSettingsService } from './escalation-settings.service';

export class UpdateEscalationSettingsDto {
  @IsInt()
  @Min(0)
  @Max(MAX_ESCALATION_MINUTES)
  ordoAfterMinutes: number;

  @IsInt()
  @Min(0)
  @Max(MAX_ESCALATION_MINUTES)
  koordinatorAfterMinutes: number;
}

@ApiTags('Parameter Pelayanan')
@Controller('master/escalation-settings')
export class EscalationController {
  constructor(private readonly settings: EscalationSettingsService) {}

  @Get()
  @Roles(...ADMIN_ROLES)
  @ApiBearerAuth('JWT-auth')
  @ApiOperation({ summary: 'Menit sampai pelayanan terbuka untuk Romo Ordo dan sampai Koordinator diberi tahu' })
  get() {
    return this.settings.get();
  }

  @Put()
  @Roles('SUPERADMIN')
  @ApiBearerAuth('JWT-auth')
  @ApiOperation({ summary: 'Ubah parameter eskalasi pelayanan (Koordinator tidak boleh lebih awal dari Romo Ordo)' })
  update(@Body() dto: UpdateEscalationSettingsDto) {
    return this.settings.update(dto);
  }
}
