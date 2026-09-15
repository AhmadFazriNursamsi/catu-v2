import {
  Controller,
  Post,
  Body,
  Get,
  Param,
  Query,
} from '@nestjs/common';
import {
  ApiTags,
  ApiOperation,
  ApiBearerAuth,
} from '@nestjs/swagger';
import { CreateOrderDto } from '../../orders.dto';
import { OrdersService } from './orders.service';

@ApiTags('Orders & Pelayanan')
@Controller('orders')
export class OrdersController {
  constructor(private readonly ordersService: OrdersService) {}

  @Post()
  @ApiBearerAuth('JWT-auth')
  @ApiOperation({
    summary: 'Membuat Pesanan Pelayanan Baru (Perminyakan / Misa Kedukaan Multi-Item)',
  })
  async createOrder(@Body() dto: CreateOrderDto) {
    return await this.ordersService.createOrder(dto);
  }

  @Get()
  @ApiBearerAuth('JWT-auth')
  @ApiOperation({ summary: 'Mendapatkan Daftar Pelayanan / Monitoring Orders dari Database PostgreSQL' })
  async getOrders(
    @Query('userId') userId?: string,
    @Query('parokiId') parokiId?: string,
    @Query('romoId') romoId?: string,
    @Query('kabupatenKotaId') kabupatenKotaId?: string,
    @Query('keuskupanId') keuskupanId?: string,
    @Query('lingkunganId') lingkunganId?: string,
    @Query('isKoordinator') isKoordinator?: string,
  ) {
    return await this.ordersService.getOrders(
      userId,
      parokiId,
      romoId,
      kabupatenKotaId,
      keuskupanId,
      lingkunganId,
      isKoordinator,
    );
  }

  @Get('available-romos')
  @ApiBearerAuth('JWT-auth')
  @ApiOperation({ summary: 'Mendapatkan daftar Romo yang aktif untuk pelimpahan/ganti romo' })
  async getAvailableRomos(@Query('parokiId') parokiId?: string) {
    return await this.ordersService.getAvailableRomos(parokiId);
  }

  @Get(':id')
  @ApiBearerAuth('JWT-auth')
  @ApiOperation({ summary: 'Mendapatkan Detail Transaksi Order Pelayanan berdasarkan ID' })
  async getOrderById(@Param('id') idParam: string) {
    return await this.ordersService.getOrderById(idParam);
  }

  @Post(':id/reschedule/propose')
  @ApiBearerAuth('JWT-auth')
  @ApiOperation({ summary: 'Romo mengajukan perubahan jadwal (reschedule) ke Umat' })
  async proposeReschedule(
    @Param('id') idParam: string,
    @Body() dto: {
      romoId: number;
      itemId?: number;
      newDate?: string;
      newTimeStart: string;
      newTimeEnd?: string;
      reason: string;
    },
  ) {
    return await this.ordersService.proposeReschedule(idParam, dto);
  }

  @Post(':id/reschedule/respond')
  @ApiBearerAuth('JWT-auth')
  @ApiOperation({ summary: 'Umat merespon (terima / tolak) pengajuan reschedule dari Romo' })
  async respondReschedule(
    @Param('id') idParam: string,
    @Body() dto: {
      userId: number;
      itemId?: number;
      action: 'ACCEPT' | 'REJECT' | 'ACCEPTED' | 'REJECTED';
    },
  ) {
    return await this.ordersService.respondReschedule(idParam, dto);
  }

  @Post(':id/handover')
  @ApiBearerAuth('JWT-auth')
  @ApiOperation({ summary: 'Romo mengajukan pelimpahan tugas pelayanan (Ganti Romo / Berhalangan)' })
  async handoverOrder(
    @Param('id') idParam: string,
    @Body() dto: {
      romoId: number;
      itemId?: number;
      targetRomoId: number;
      reason: string;
    },
  ) {
    return await this.ordersService.handoverOrder(idParam, dto);
  }

  @Post(':id/handover/respond')
  @ApiBearerAuth('JWT-auth')
  @ApiOperation({ summary: 'Romo Baru menerima atau menolak pelimpahan tugas pelayanan' })
  async respondHandover(
    @Param('id') idParam: string,
    @Body() dto: {
      romoId: number;
      itemId?: number;
      action: 'ACCEPT' | 'REJECT';
    },
  ) {
    return await this.ordersService.respondHandover(idParam, dto);
  }
}
