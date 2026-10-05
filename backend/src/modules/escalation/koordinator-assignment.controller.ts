import { Body, Controller, Get, Param, ParseIntPipe, Post } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { IsIn, IsInt, IsOptional, IsString, Min, MinLength } from 'class-validator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { Roles } from '../../common/decorators/roles.decorator';
import { AuthUser } from '../../common/access/access.service';
import { ADMIN_ROLES } from '../../common/access/role-groups';
import { KoordinatorAssignmentService } from './koordinator-assignment.service';

export class KoordinatorAssignDto {
  @IsInt()
  @Min(1)
  romoId: number;

  @IsOptional()
  @IsInt()
  @Min(1)
  itemId?: number;
}

export class RegisterRomoDto {
  @IsString()
  @MinLength(3)
  fullName: string;

  @IsString()
  phoneNumber: string;

  @IsIn(['ROMO_PAROKI', 'ROMO_ORDO'])
  roleCode: 'ROMO_PAROKI' | 'ROMO_ORDO';

  @IsOptional()
  @IsInt()
  parokiId?: number;

  @IsOptional()
  @IsInt()
  ordoId?: number;

  /** Misa yang ditetapkan; kosong = semua misa yang belum diterima. */
  @IsOptional()
  @IsInt()
  @Min(1)
  itemId?: number;
}

const KOORDINATOR_ROLES = ['KOORDINATOR', 'KOORDINATOR_KEUSKUPAN'];

@ApiTags('Koordinator Mencarikan Romo')
@Controller('orders/:orderId/koordinator-assignment')
export class KoordinatorAssignmentController {
  constructor(private readonly service: KoordinatorAssignmentService) {}

  @Get()
  @Roles(...KOORDINATOR_ROLES, ...ADMIN_ROLES)
  @ApiBearerAuth('JWT-auth')
  @ApiOperation({ summary: 'Status pencarian Romo oleh Koordinator + daftar seluruh Romo terdaftar (bila sudah waktunya)' })
  get(@CurrentUser() user: AuthUser, @Param('orderId', ParseIntPipe) orderId: number) {
    return this.service.get(user, orderId);
  }

  @Get('register-options')
  @Roles(...KOORDINATOR_ROLES, ...ADMIN_ROLES)
  @ApiBearerAuth('JWT-auth')
  @ApiOperation({ summary: 'Pilihan paroki dan ordo untuk mendaftarkan Romo yang belum terdaftar' })
  registerOptions(@CurrentUser() user: AuthUser, @Param('orderId', ParseIntPipe) orderId: number) {
    return this.service.registerOptions(user, orderId);
  }

  @Post('register-romo')
  @Roles(...KOORDINATOR_ROLES, ...ADMIN_ROLES)
  @ApiBearerAuth('JWT-auth')
  @ApiOperation({ summary: 'Koordinator mendaftarkan Romo yang belum terdaftar: langsung aktif, kata sandi otomatis, dan pelayanan otomatis diterima Romo tersebut' })
  registerRomo(@CurrentUser() user: AuthUser, @Param('orderId', ParseIntPipe) orderId: number, @Body() dto: RegisterRomoDto) {
    return this.service.registerRomo(user, orderId, dto);
  }

  @Post()
  @Roles(...KOORDINATOR_ROLES, ...ADMIN_ROLES)
  @ApiBearerAuth('JWT-auth')
  @ApiOperation({ summary: 'Koordinator memilih Romo; pelayanan otomatis diterima atas nama Romo tersebut' })
  assign(@CurrentUser() user: AuthUser, @Param('orderId', ParseIntPipe) orderId: number, @Body() dto: KoordinatorAssignDto) {
    return this.service.assign(user, orderId, dto);
  }
}
