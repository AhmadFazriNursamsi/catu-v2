import {
  Controller,
  Get,
  Post,
  Put,
  Delete,
  Body,
  Param,
  Query,
  UseGuards,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { GeoMasterDataService } from './geo-master-data.service';
import {
  CreateProvinsiDto,
  UpdateProvinsiDto,
  CreateKabupatenKotaDto,
  UpdateKabupatenKotaDto,
} from './geo-master-data.dto';

@ApiTags('Master Data Wilayah Geografis (Provinsi & Kota)')
@Controller('master')
export class GeoMasterDataController {
  constructor(private readonly geoService: GeoMasterDataService) {}

  // ── PROVINSI ──
  @Get('provinsi')
  @ApiOperation({ summary: 'Daftar Semua Provinsi' })
  async getAllProvinsi() {
    return await this.geoService.getAllProvinsi();
  }

  @Post('provinsi')
  @ApiBearerAuth('JWT-auth')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('SUPERADMIN', 'ADMIN')
  @ApiOperation({ summary: 'Tambah Provinsi Baru' })
  async createProvinsi(@Body() dto: CreateProvinsiDto) {
    return await this.geoService.createProvinsi(dto);
  }

  @Put('provinsi/:id')
  @ApiBearerAuth('JWT-auth')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('SUPERADMIN', 'ADMIN')
  @ApiOperation({ summary: 'Update Data Provinsi' })
  async updateProvinsi(@Param('id') id: string, @Body() dto: UpdateProvinsiDto) {
    return await this.geoService.updateProvinsi(parseInt(id, 10), dto);
  }

  @Delete('provinsi/:id')
  @ApiBearerAuth('JWT-auth')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('SUPERADMIN', 'ADMIN')
  @ApiOperation({ summary: 'Hapus Provinsi' })
  async deleteProvinsi(@Param('id') id: string) {
    return await this.geoService.deleteProvinsi(parseInt(id, 10));
  }

  // ── KABUPATEN / KOTA ──
  @Get('kabupaten-kota')
  @ApiOperation({ summary: 'Daftar Semua Kabupaten/Kota' })
  async getAllKabupatenKota(@Query('provinsiId') provinsiId?: string) {
    const pId = provinsiId ? parseInt(provinsiId, 10) : undefined;
    return await this.geoService.getAllKabupatenKota(pId);
  }

  @Post('kabupaten-kota')
  @ApiBearerAuth('JWT-auth')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('SUPERADMIN', 'ADMIN')
  @ApiOperation({ summary: 'Tambah Kabupaten/Kota Baru' })
  async createKabupatenKota(@Body() dto: CreateKabupatenKotaDto) {
    return await this.geoService.createKabupatenKota(dto);
  }

  @Put('kabupaten-kota/:id')
  @ApiBearerAuth('JWT-auth')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('SUPERADMIN', 'ADMIN')
  @ApiOperation({ summary: 'Update Data Kabupaten/Kota' })
  async updateKabupatenKota(@Param('id') id: string, @Body() dto: UpdateKabupatenKotaDto) {
    return await this.geoService.updateKabupatenKota(parseInt(id, 10), dto);
  }

  @Delete('kabupaten-kota/:id')
  @ApiBearerAuth('JWT-auth')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('SUPERADMIN', 'ADMIN')
  @ApiOperation({ summary: 'Hapus Kabupaten/Kota' })
  async deleteKabupatenKota(@Param('id') id: string) {
    return await this.geoService.deleteKabupatenKota(parseInt(id, 10));
  }
}
