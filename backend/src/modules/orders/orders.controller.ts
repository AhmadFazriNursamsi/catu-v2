import {
  BadRequestException,
  Controller,
  Logger,
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
import { OrderReviewsService } from './order-reviews.service';
import { validateRescheduleProposal } from './reschedule-validation';
import { validateNewOrder } from '../order-rules/order-input-rules';
import { OrderGuardsService } from '../order-rules/order-guards.service';
import { LintasParokiService } from '../order-rules/lintas-paroki.service';
import { MAX_RESCHEDULE_REJECTIONS, OrderEventsService } from '../order-events/order-events.service';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { Roles } from '../../common/decorators/roles.decorator';
import { AccessService, AuthUser } from '../../common/access/access.service';
import { ADMIN_ROLES, ROMO_ROLES } from '../../common/access/role-groups';

@ApiTags('Orders & Pelayanan')
@Controller('orders')
export class OrdersController {
  constructor(
    private readonly ordersService: OrdersService,
    private readonly orderReviewsService: OrderReviewsService,
    private readonly access: AccessService,
    private readonly events: OrderEventsService,
    private readonly guards: OrderGuardsService,
    private readonly lintas: LintasParokiService,
  ) {}

  private readonly logger = new Logger(OrdersController.name);

  /** Identitas aktor selalu dari token; admin boleh bertindak atas nama pengguna lain. */
  private actor(user: AuthUser, requested?: number): number | undefined {
    return this.access.isAdmin(user) ? requested ?? user.sub : user.sub;
  }

  /** Setelah Umat menolak: umumkan sisa kesempatan, atau penutupan bila batas penolakan tercapai. */
  private async afterRescheduleRejected(orderId: number, itemId?: number) {
    const rejected = await this.events.rejectedRescheduleCount(orderId, itemId);
    const closed = rejected >= MAX_RESCHEDULE_REJECTIONS;
    const name = await this.events.itemName(orderId, itemId);
    const label = name ? ` untuk ${name}` : '';
    await this.events.postChat(
      orderId,
      itemId,
      closed
        ? `Pengajuan ubah jam${label} telah ditolak ${rejected} kali dan sekarang DITUTUP. Pelayanan dilaksanakan sesuai jadwal terakhir.`
        : `Pengajuan ubah jam${label} ditolak. Romo masih dapat mengajukan ${MAX_RESCHEDULE_REJECTIONS - rejected} kali lagi.`,
    );
    if (closed) {
      await this.events.notify([await this.events.lastRescheduleProposer(orderId, itemId)], {
        orderId,
        itemId,
        type: 'RESCHEDULE_CLOSED',
        title: `Ubah Jam Ditutup${name ? `: ${name}` : ''}`,
        body: `Pengajuan ubah jam telah ditolak ${rejected} kali. Jadwal tidak dapat diubah lagi.`,
      });
    }
    return { rejectedCount: rejected, rescheduleClosed: closed };
  }

  @Post()
  @ApiBearerAuth('JWT-auth')
  @ApiOperation({
    summary: 'Membuat Pesanan Pelayanan Baru (Perminyakan / Misa Kedukaan Multi-Item)',
  })
  async createOrder(@CurrentUser() user: AuthUser, @Body() dto: CreateOrderDto) {
    const invalid = validateNewOrder(dto);
    if (invalid) throw new BadRequestException(invalid);
    await this.guards.assertNewOrderRefs(dto);
    const result = await this.ordersService.createOrder({ ...dto, userId: this.actor(user, dto.userId) });
    // Pelayanan lintas paroki: teruskan ke Romo Ordo tujuan dan libatkan Koordinator (kegagalan di sini tidak membatalkan order).
    await this.lintas.afterCreate(result.order.id).catch((err) => this.logger.error(`Gagal memproses pelayanan lintas paroki: ${err.message}`));
    return result;
  }

  @Get()
  @ApiBearerAuth('JWT-auth')
  @ApiOperation({ summary: 'Mendapatkan Daftar Pelayanan / Monitoring Orders dari Database PostgreSQL' })
  async getOrders(
    @CurrentUser() user: AuthUser,
    @Query('userId') userId?: string,
    @Query('parokiId') parokiId?: string,
    @Query('romoId') romoId?: string,
    @Query('kabupatenKotaId') kabupatenKotaId?: string,
    @Query('keuskupanId') keuskupanId?: string,
    @Query('lingkunganId') lingkunganId?: string,
    @Query('isKoordinator') isKoordinator?: string,
  ) {
    // Umat dan Koordinator hanya melihat order miliknya sendiri, filter scope dari klien diabaikan.
    if (this.access.isEndUser(user) || user.roleCode.includes('KOORDINATOR')) {
      return await this.ordersService.getOrders(String(user.sub));
    }
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
  async getOrderById(@CurrentUser() user: AuthUser, @Param('id') idParam: string) {
    await this.access.assertOrderAccess(user, idParam);
    return await this.ordersService.getOrderById(idParam);
  }

  @Post(':id/reschedule/propose')
  @Roles(...ROMO_ROLES, ...ADMIN_ROLES)
  @ApiBearerAuth('JWT-auth')
  @ApiOperation({ summary: 'Romo mengajukan perubahan jadwal (reschedule) ke Umat' })
  async proposeReschedule(
    @CurrentUser() user: AuthUser,
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
    const invalid = validateRescheduleProposal(dto, new Date(), (await this.guards.scheduledDate(Number(idParam), dto.itemId)) ?? undefined);
    if (invalid) throw new BadRequestException(invalid);
    await this.events.assertRescheduleOpen(Number(idParam), dto.itemId);
    await this.guards.assertRescheduleProposable(Number(idParam), dto.itemId);
    return await this.ordersService.proposeReschedule(idParam, {
      ...dto,
      romoId: this.actor(user, dto.romoId) as number,
    });
  }

  @Post(':id/reschedule/respond')
  @ApiBearerAuth('JWT-auth')
  @ApiOperation({ summary: 'Umat merespon (terima / tolak) pengajuan reschedule dari Romo' })
  async respondReschedule(
    @CurrentUser() user: AuthUser,
    @Param('id') idParam: string,
    @Body() dto: {
      userId: number;
      itemId?: number;
      action: 'ACCEPT' | 'REJECT' | 'ACCEPTED' | 'REJECTED';
    },
  ) {
    await this.access.assertOrderAccess(user, idParam);
    await this.guards.assertReschedulePending(Number(idParam), dto.itemId);
    const result: any = await this.ordersService.respondReschedule(idParam, {
      ...dto,
      userId: this.actor(user, dto.userId) as number,
    });
    if (result?.statusCode === 200 && /^REJECT/i.test(dto.action)) {
      return { ...result, ...(await this.afterRescheduleRejected(Number(idParam), dto.itemId)) };
    }
    return result;
  }

  @Post(':id/handover')
  @Roles(...ROMO_ROLES, ...ADMIN_ROLES)
  @ApiBearerAuth('JWT-auth')
  @ApiOperation({ summary: 'Romo mengajukan pelimpahan tugas pelayanan (Ganti Romo / Berhalangan)' })
  async handoverOrder(
    @CurrentUser() user: AuthUser,
    @Param('id') idParam: string,
    @Body() dto: {
      romoId: number;
      itemId?: number;
      targetRomoId?: number;
      externalRomoName?: string;
      reason: string;
    },
  ) {
    const romoId = this.actor(user, dto.romoId) as number;
    await this.guards.assertHandoverAllowed(Number(idParam), dto.itemId, { ...dto, romoId });
    return await this.ordersService.handoverOrder(idParam, { ...dto, romoId });
  }

  @Post(':id/handover/respond')
  @Roles(...ROMO_ROLES, ...ADMIN_ROLES)
  @ApiBearerAuth('JWT-auth')
  @ApiOperation({ summary: 'Romo Baru menerima atau menolak pelimpahan tugas pelayanan' })
  async respondHandover(
    @CurrentUser() user: AuthUser,
    @Param('id') idParam: string,
    @Body() dto: {
      romoId: number;
      itemId?: number;
      action: 'ACCEPT' | 'REJECT';
    },
  ) {
    await this.guards.assertHandoverPending(Number(idParam), dto.itemId);
    return await this.ordersService.respondHandover(idParam, {
      ...dto,
      romoId: this.actor(user, dto.romoId) as number,
    });
  }

  @Post(':id/review')
  @ApiBearerAuth('JWT-auth')
  @ApiOperation({ summary: 'Umat memberikan ulasan pada pelayanan yang telah selesai atau ditutup' })
  async submitReview(
    @CurrentUser() user: AuthUser,
    @Param('id') idParam: string,
    @Body() dto: {
      userId?: number;
      itemId?: number;
      rating?: number;
      reviewNotes: string;
    },
  ) {
    await this.access.assertOrderAccess(user, idParam);
    const result = await this.orderReviewsService.submitReview(idParam, {
      ...dto,
      userId: this.actor(user, dto.userId),
    });
    const orderId = Number(idParam);
    const name = await this.events.itemName(orderId, dto.itemId);
    await this.events.postChat(orderId, dto.itemId, `Umat pemohon telah memberikan ulasan${name ? ` untuk ${name}` : ''}. Terima kasih atas pelayanannya.`);
    return result;
  }
}
