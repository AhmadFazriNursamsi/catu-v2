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
import { SkipThrottle } from '@nestjs/throttler';
import { NotificationsService } from './notifications.service';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { AllowInactiveAccount } from '../../common/decorators/allow-inactive.decorator';
import { AccessService, AuthUser } from '../../common/access/access.service';

@ApiTags('Notifications')
@ApiBearerAuth('JWT-auth')
@Controller('notifications')
export class NotificationsController {
  constructor(
    private readonly notificationsService: NotificationsService,
    private readonly access: AccessService,
  ) {}

  @AllowInactiveAccount()
  @Post('register-device')
  @ApiOperation({ summary: 'Mendaftarkan FCM device token untuk push notification' })
  async registerDevice(
    @CurrentUser() user: AuthUser,
    @Body() body: { userId: number; fcmToken: string; deviceType?: string; deviceModel?: string },
  ) {
    this.access.assertSelf(user, body.userId);
    return await this.notificationsService.registerDevice(body);
  }

  @AllowInactiveAccount()
  @Post('unregister-device')
  @ApiOperation({ summary: 'Menghapus FCM device token saat logout' })
  async unregisterDevice(
    @CurrentUser() user: AuthUser,
    @Body() body: { userId: number; fcmToken: string },
  ) {
    this.access.assertSelf(user, body.userId);
    return await this.notificationsService.unregisterDevice(body);
  }

  @Post('test-push')
  @ApiOperation({ summary: 'Kirim test push notification ke perangkat milik sendiri' })
  async testPush(
    @CurrentUser() user: AuthUser,
    @Body() body: { userId: number; title?: string; message?: string },
  ) {
    this.access.assertSelf(user, body.userId);
    return await this.notificationsService.testPush(body);
  }

  @SkipThrottle()
  @AllowInactiveAccount()
  @Get()
  @ApiOperation({ summary: 'Mendapatkan daftar notifikasi untuk user' })
  async getNotifications(
    @CurrentUser() user: AuthUser,
    @Query('userId') userId?: string,
    @Query('role') role?: string,
  ) {
    const effectiveUserId = this.access.isAdmin(user) ? userId : String(user.sub);
    return await this.notificationsService.getNotifications(effectiveUserId, role);
  }

  @AllowInactiveAccount()
  @Post(':id/read')
  @ApiOperation({ summary: 'Tandai notifikasi sebagai sudah dibaca' })
  async markRead(@CurrentUser() user: AuthUser, @Param('id') idParam: string) {
    const notifId = parseInt(idParam, 10);
    await this.access.assertNotificationOwner(user, notifId);
    return await this.notificationsService.markRead(notifId);
  }

  @AllowInactiveAccount()
  @Post('read-all')
  @ApiOperation({ summary: 'Tandai semua notifikasi user sebagai sudah dibaca' })
  async markAllRead(@CurrentUser() user: AuthUser) {
    return await this.notificationsService.markAllRead(user.sub);
  }

  @Delete('user/:userId')
  @ApiOperation({ summary: 'Hapus semua notifikasi untuk user' })
  async deleteAllForUser(@CurrentUser() user: AuthUser, @Param('userId') userIdParam: string) {
    this.access.assertSelf(user, userIdParam);
    const userId = parseInt(userIdParam, 10);
    return await this.notificationsService.deleteAllForUser(userId);
  }

  @Delete(':id')
  @ApiOperation({ summary: 'Hapus notifikasi' })
  async deleteNotification(@CurrentUser() user: AuthUser, @Param('id') idParam: string) {
    const notifId = parseInt(idParam, 10);
    await this.access.assertNotificationOwner(user, notifId);
    return await this.notificationsService.deleteNotification(notifId);
  }
}
