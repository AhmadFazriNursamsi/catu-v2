import {
  Controller,
  Post,
  Put,
  Delete,
  Body,
  Get,
  Param,
  Query,
  OnModuleInit,
  BadRequestException,
  NotFoundException,
  HttpCode,
} from '@nestjs/common';
import {
  ApiTags,
  ApiOperation,
  ApiResponse,
  ApiBearerAuth,
} from '@nestjs/swagger';
import { InjectDataSource } from '@nestjs/typeorm';
import { DataSource } from 'typeorm';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcrypt';
import {
  RegisterUserDto,
  LoginDto,
  ApproveUserDto,
  RegisterResponseDto,
  LoginResponseDto,
  ApproveUserResponseDto,
  RoleCodeEnum,
  RequestResetOtpDto,
  VerifyResetOtpDto,
  ResetPasswordDto,
} from '../../auth.dto';
import {
  CreateOrderDto,
  RespondOrderAssignmentDto,
  SendChatMessageDto,
  UpdateUserProfileDto,
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
import { FcmService } from '../../fcm.service';

@ApiTags('Notifications')
@Controller('notifications')
export class NotificationsController {
  constructor(
    @InjectDataSource() private dataSource: DataSource,
    private readonly fcmService: FcmService,
  ) {}

  @Post('register-device')
  @ApiOperation({ summary: 'Mendaftarkan FCM device token untuk push notification' })
  async registerDevice(
    @Body() body: { userId: number; fcmToken: string; deviceType?: string; deviceModel?: string },
  ) {
    if (!body.userId || !body.fcmToken) {
      return { success: false, message: 'userId and fcmToken are required' };
    }
    return await this.fcmService.registerDeviceToken(
      body.userId,
      body.fcmToken,
      body.deviceType || 'ANDROID',
      body.deviceModel,
    );
  }

  @Post('unregister-device')
  @ApiOperation({ summary: 'Menghapus FCM device token saat logout' })
  async unregisterDevice(
    @Body() body: { userId: number; fcmToken: string },
  ) {
    if (!body.userId || !body.fcmToken) {
      return { success: false, message: 'userId and fcmToken are required' };
    }
    return await this.fcmService.unregisterDeviceToken(body.userId, body.fcmToken);
  }

  @Post('test-push')
  @ApiOperation({ summary: 'Kirim test push notification ke user' })
  async testPush(
    @Body() body: { userId: number; title?: string; message?: string },
  ) {
    if (!body.userId) {
      return { success: false, message: 'userId is required' };
    }
    const res = await this.fcmService.sendPushToUsers(body.userId, {
      title: body.title || '🔔 Tes Notifikasi CATU',
      body: body.message || 'Push notification Firebase FCM berhasil terhubung dengan server CATU!',
      data: { type: 'TEST_PUSH', timestamp: new Date().toISOString() },
    });
    return { success: true, result: res };
  }

  @Get()
  @ApiBearerAuth('JWT-auth')
  @ApiOperation({ summary: 'Mendapatkan daftar notifikasi untuk user' })
  async getNotifications(
    @Query('userId') userId?: string,
    @Query('role') role?: string,
  ) {
    const whereClauses: string[] = [];
    const queryParams: any[] = [];
    let idx = 1;

    if (userId && !isNaN(parseInt(userId))) {
      whereClauses.push(`n.user_id = $${idx++}`);
      queryParams.push(parseInt(userId));
    }

    const whereStr = whereClauses.length > 0 ? `WHERE ${whereClauses.join(' AND ')}` : '';
    const query = `
      SELECT n.id, n.user_id as "userId", n.order_id as "orderId",
             COALESCE(n.chat_group_id, cg.id) as "groupId",
             n.title, n.body, n.type, n.is_read as "isRead", n.created_at as "createdAt",
             o.order_number as "orderNumber", sc.name as "categoryName",
             o.status as "orderStatus"
      FROM notifications n
      LEFT JOIN orders o ON n.order_id = o.id
      LEFT JOIN service_categories sc ON o.service_category_id = sc.id
      LEFT JOIN LATERAL (
        SELECT id FROM chat_groups WHERE order_id = n.order_id ORDER BY id ASC LIMIT 1
      ) cg ON n.chat_group_id IS NULL
      ${whereStr}
      ORDER BY n.id DESC LIMIT 100
    `;
    return await this.dataSource.query(query, queryParams);
  }

  @Post(':id/read')
  @ApiBearerAuth('JWT-auth')
  @ApiOperation({ summary: 'Tandai notifikasi sebagai sudah dibaca' })
  async markRead(@Param('id') idParam: string) {
    const notifId = parseInt(idParam, 10);
    if (!isNaN(notifId)) {
      await this.dataSource.query('UPDATE notifications SET is_read = true WHERE id = $1', [notifId]);
    }
    return { success: true };
  }

  @Post('read-all')
  @ApiBearerAuth('JWT-auth')
  @ApiOperation({ summary: 'Tandai semua notifikasi user sebagai sudah dibaca' })
  async markAllRead(@Body() body: { userId: number }) {
    if (body.userId) {
      await this.dataSource.query('UPDATE notifications SET is_read = true WHERE user_id = $1', [body.userId]);
    }
    return { success: true };
  }

  @Delete(':id')
  @ApiBearerAuth('JWT-auth')
  @ApiOperation({ summary: 'Hapus notifikasi' })
  async deleteNotification(@Param('id') idParam: string) {
    const notifId = parseInt(idParam, 10);
    if (!isNaN(notifId)) {
      await this.dataSource.query('DELETE FROM notifications WHERE id = $1', [notifId]);
    }
    return { success: true };
  }
}
