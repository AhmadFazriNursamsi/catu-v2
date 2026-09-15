import {
  Controller,
  Post,
  Delete,
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
import { NotificationsService } from './notifications.service';

@ApiTags('Notifications')
@Controller('notifications')
export class NotificationsController {
  constructor(private readonly notificationsService: NotificationsService) {}

  @Post('register-device')
  @ApiOperation({ summary: 'Mendaftarkan FCM device token untuk push notification' })
  async registerDevice(
    @Body() body: { userId: number; fcmToken: string; deviceType?: string; deviceModel?: string },
  ) {
    return await this.notificationsService.registerDevice(body);
  }

  @Post('unregister-device')
  @ApiOperation({ summary: 'Menghapus FCM device token saat logout' })
  async unregisterDevice(
    @Body() body: { userId: number; fcmToken: string },
  ) {
    return await this.notificationsService.unregisterDevice(body);
  }

  @Post('test-push')
  @ApiOperation({ summary: 'Kirim test push notification ke user' })
  async testPush(
    @Body() body: { userId: number; title?: string; message?: string },
  ) {
    return await this.notificationsService.testPush(body);
  }

  @Get()
  @ApiBearerAuth('JWT-auth')
  @ApiOperation({ summary: 'Mendapatkan daftar notifikasi untuk user' })
  async getNotifications(
    @Query('userId') userId?: string,
    @Query('role') role?: string,
  ) {
    return await this.notificationsService.getNotifications(userId, role);
  }

  @Post(':id/read')
  @ApiBearerAuth('JWT-auth')
  @ApiOperation({ summary: 'Tandai notifikasi sebagai sudah dibaca' })
  async markRead(@Param('id') idParam: string) {
    const notifId = parseInt(idParam, 10);
    return await this.notificationsService.markRead(notifId);
  }

  @Post('read-all')
  @ApiBearerAuth('JWT-auth')
  @ApiOperation({ summary: 'Tandai semua notifikasi user sebagai sudah dibaca' })
  async markAllRead(@Body() body: { userId: number }) {
    return await this.notificationsService.markAllRead(body.userId);
  }

  @Delete(':id')
  @ApiBearerAuth('JWT-auth')
  @ApiOperation({ summary: 'Hapus notifikasi' })
  async deleteNotification(@Param('id') idParam: string) {
    const notifId = parseInt(idParam, 10);
    return await this.notificationsService.deleteNotification(notifId);
  }
}
