import {
  Controller,
  Post,
  Put,
  Delete,
  Body,
  Get,
  Param,
  Query,
  UseGuards,
} from '@nestjs/common';
import {
  ApiTags,
  ApiOperation,
  ApiBearerAuth,
} from '@nestjs/swagger';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import {
  CreateKeuskupanDto,
  UpdateKeuskupanDto,
  CreateParokiDto,
  UpdateParokiDto,
  CreateWilayahDto,
  UpdateWilayahDto,
  CreateLingkunganDto,
  UpdateLingkunganDto,
  CreateOrdoDto,
  UpdateOrdoDto,
  CreateServiceCategoryDto,
  UpdateServiceCategoryDto,
  CreateRoleDto,
  UpdateRoleDto,
  CreatePositionDto,
  UpdatePositionDto,
} from '../../orders.dto';
import { MasterDataService } from './master-data.service';

@ApiTags('Master Data Gereja & Wilayah')
@Controller('master')
export class MasterDataController {
  constructor(private readonly masterDataService: MasterDataService) {}

  // 1. KEUSKUPAN
  @Get('keuskupan')
  @ApiOperation({ summary: 'Daftar Semua Keuskupan dari Database' })
  async getAllKeuskupan() {
    return await this.masterDataService.getAllKeuskupan();
  }

  @Post('keuskupan')
  @ApiOperation({ summary: 'Tambah Keuskupan Baru ke Database' })
  async createKeuskupan(@Body() dto: CreateKeuskupanDto) {
    return await this.masterDataService.createKeuskupan(dto);
  }

  @Put('keuskupan/:id')
  @ApiOperation({ summary: 'Update Data Keuskupan di Database' })
  async updateKeuskupan(@Param('id') id: number, @Body() dto: UpdateKeuskupanDto) {
    return await this.masterDataService.updateKeuskupan(id, dto);
  }

  @Delete('keuskupan/:id')
  @ApiOperation({ summary: 'Hapus Keuskupan dari Database' })
  async deleteKeuskupan(@Param('id') id: number) {
    return await this.masterDataService.deleteKeuskupan(id);
  }

  // 2. PAROKI
  @Get('paroki')
  @ApiOperation({ summary: 'Daftar Semua Paroki dari Database' })
  async getAllParoki(@Query('keuskupanId') keuskupanId?: number) {
    return await this.masterDataService.getAllParoki(keuskupanId);
  }

  @Post('paroki')
  @ApiOperation({ summary: 'Tambah Paroki Baru ke Database' })
  async createParoki(@Body() dto: CreateParokiDto) {
    return await this.masterDataService.createParoki(dto);
  }

  @Put('paroki/:id')
  @ApiOperation({ summary: 'Update Data Paroki di Database' })
  async updateParoki(@Param('id') id: number, @Body() dto: UpdateParokiDto) {
    return await this.masterDataService.updateParoki(id, dto);
  }

  @Delete('paroki/:id')
  @ApiOperation({ summary: 'Hapus Paroki dari Database' })
  async deleteParoki(@Param('id') id: number) {
    return await this.masterDataService.deleteParoki(id);
  }

  // 3. WILAYAH
  @Get('wilayah')
  @ApiOperation({ summary: 'Daftar Semua Wilayah dari Database' })
  async getAllWilayah(@Query('parokiId') parokiId?: number) {
    return await this.masterDataService.getAllWilayah(parokiId);
  }

  @Post('wilayah')
  @ApiOperation({ summary: 'Tambah Wilayah Baru ke Database' })
  async createWilayah(@Body() dto: CreateWilayahDto) {
    return await this.masterDataService.createWilayah(dto);
  }

  @Put('wilayah/:id')
  @ApiOperation({ summary: 'Update Data Wilayah di Database' })
  async updateWilayah(@Param('id') id: number, @Body() dto: UpdateWilayahDto) {
    return await this.masterDataService.updateWilayah(id, dto);
  }

  @Delete('wilayah/:id')
  @ApiOperation({ summary: 'Hapus Wilayah dari Database' })
  async deleteWilayah(@Param('id') id: number) {
    return await this.masterDataService.deleteWilayah(id);
  }

  // 4. LINGKUNGAN
  @Get('lingkungan')
  @ApiOperation({ summary: 'Daftar Semua Lingkungan dari Database' })
  async getAllLingkungan(@Query('wilayahId') wilayahId?: number) {
    return await this.masterDataService.getAllLingkungan(wilayahId);
  }

  @Post('lingkungan')
  @ApiOperation({ summary: 'Tambah Lingkungan Baru ke Database' })
  async createLingkungan(@Body() dto: CreateLingkunganDto) {
    return await this.masterDataService.createLingkungan(dto);
  }

  @Put('lingkungan/:id')
  @ApiOperation({ summary: 'Update Data Lingkungan di Database' })
  async updateLingkungan(@Param('id') id: number, @Body() dto: UpdateLingkunganDto) {
    return await this.masterDataService.updateLingkungan(id, dto);
  }

  @Delete('lingkungan/:id')
  @ApiOperation({ summary: 'Hapus Lingkungan dari Database' })
  async deleteLingkungan(@Param('id') id: number) {
    return await this.masterDataService.deleteLingkungan(id);
  }

  // 5. ORDO
  @Get('ordo')
  @ApiOperation({ summary: 'Daftar Semua Ordo / Kongregasi dari Database' })
  async getAllOrdo() {
    return await this.masterDataService.getAllOrdo();
  }

  @Post('ordo')
  @ApiOperation({ summary: 'Tambah Ordo Baru ke Database' })
  async createOrdo(@Body() dto: CreateOrdoDto) {
    return await this.masterDataService.createOrdo(dto);
  }

  @Put('ordo/:id')
  @ApiOperation({ summary: 'Update Data Ordo di Database' })
  async updateOrdo(@Param('id') id: number, @Body() dto: UpdateOrdoDto) {
    return await this.masterDataService.updateOrdo(id, dto);
  }

  @Delete('ordo/:id')
  @ApiOperation({ summary: 'Hapus Ordo dari Database' })
  async deleteOrdo(@Param('id') id: number) {
    return await this.masterDataService.deleteOrdo(id);
  }

  // 6. SERVICE CATEGORIES
  @Get('service-categories')
  @ApiOperation({ summary: 'Daftar Kategori Pelayanan dari Database' })
  async getAllServiceCategories() {
    return await this.masterDataService.getAllServiceCategories();
  }

  @Post('service-categories')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('SUPERADMIN')
  @ApiBearerAuth('JWT-auth')
  @ApiOperation({ summary: 'Tambah Kategori Pelayanan Baru (Superadmin Only)' })
  async createServiceCategory(@Body() dto: CreateServiceCategoryDto) {
    return await this.masterDataService.createServiceCategory(dto);
  }

  @Put('service-categories/:id')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('SUPERADMIN')
  @ApiBearerAuth('JWT-auth')
  @ApiOperation({ summary: 'Update Kategori Pelayanan (Superadmin Only)' })
  async updateServiceCategory(@Param('id') id: number, @Body() dto: UpdateServiceCategoryDto) {
    return await this.masterDataService.updateServiceCategory(id, dto);
  }

  @Delete('service-categories/:id')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('SUPERADMIN')
  @ApiBearerAuth('JWT-auth')
  @ApiOperation({ summary: 'Hapus Kategori Pelayanan (Superadmin Only)' })
  async deleteServiceCategory(@Param('id') id: number) {
    return await this.masterDataService.deleteServiceCategory(id);
  }

  // 7. ROLES
  @Get('roles')
  @ApiOperation({ summary: 'Daftar Semua Jenis Role / Pengguna dari Database' })
  async getAllRoles() {
    return await this.masterDataService.getAllRoles();
  }

  @Post('roles')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('SUPERADMIN')
  @ApiBearerAuth('JWT-auth')
  @ApiOperation({ summary: 'Tambah Jenis Role Baru (Superadmin Only)' })
  async createRole(@Body() dto: CreateRoleDto) {
    return await this.masterDataService.createRole(dto);
  }

  @Put('roles/:id')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('SUPERADMIN')
  @ApiBearerAuth('JWT-auth')
  @ApiOperation({ summary: 'Update Data Jenis Role (Superadmin Only)' })
  async updateRole(@Param('id') id: number, @Body() dto: UpdateRoleDto) {
    return await this.masterDataService.updateRole(id, dto);
  }

  @Delete('roles/:id')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('SUPERADMIN')
  @ApiBearerAuth('JWT-auth')
  @ApiOperation({ summary: 'Hapus Jenis Role (Superadmin Only)' })
  async deleteRole(@Param('id') id: number) {
    return await this.masterDataService.deleteRole(id);
  }

  // 8. POSITIONS
  @Get('positions')
  @ApiOperation({ summary: 'Daftar Semua Jabatan / Posisi dari Database' })
  async getAllPositions(@Query('category') category?: string) {
    return await this.masterDataService.getAllPositions(category);
  }

  @Post('positions')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('SUPERADMIN')
  @ApiBearerAuth('JWT-auth')
  @ApiOperation({ summary: 'Tambah Jabatan / Posisi Baru (Superadmin Only)' })
  async createPosition(@Body() dto: CreatePositionDto) {
    return await this.masterDataService.createPosition(dto);
  }

  @Put('positions/:id')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('SUPERADMIN')
  @ApiBearerAuth('JWT-auth')
  @ApiOperation({ summary: 'Update Data Jabatan / Posisi (Superadmin Only)' })
  async updatePosition(@Param('id') id: number, @Body() dto: UpdatePositionDto) {
    return await this.masterDataService.updatePosition(id, dto);
  }

  @Delete('positions/:id')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('SUPERADMIN')
  @ApiBearerAuth('JWT-auth')
  @ApiOperation({ summary: 'Hapus Jabatan / Posisi (Superadmin Only)' })
  async deletePosition(@Param('id') id: number) {
    return await this.masterDataService.deletePosition(id);
  }
}
