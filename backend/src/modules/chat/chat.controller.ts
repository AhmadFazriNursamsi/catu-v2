import {
  Controller,
  Post,
  Body,
  Get,
  Param,
  Query,
  ForbiddenException,
} from '@nestjs/common';
import {
  ApiTags,
  ApiOperation,
  ApiBearerAuth,
} from '@nestjs/swagger';
import { SendChatMessageDto } from '../../orders.dto';
import { ChatService } from './chat.service';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { Roles } from '../../common/decorators/roles.decorator';
import { AccessService, AuthUser } from '../../common/access/access.service';
import { ADMIN_ROLES } from '../../common/access/role-groups';

@ApiTags('Group Chat')
@Controller('chat')
export class ChatController {
  constructor(
    private readonly chatService: ChatService,
    private readonly access: AccessService,
  ) {}

  /** Anggota dihitung oleh ChatService (pemohon, Romo, pengurus lingkungan); admin dan koordinator (scope) dikecualikan. */
  private async assertMember(user: AuthUser, groupIdParam: string): Promise<void> {
    if (this.access.isAdmin(user) || user.roleCode.includes('KOORDINATOR')) return;
    const members = await this.chatService.getGroupMembers(groupIdParam);
    if (!members.some((m: any) => Number(m.user_id) === Number(user.sub))) {
      throw new ForbiddenException('Akses ditolak: Anda bukan anggota grup chat ini');
    }
  }

  @Get('order/:orderId')
  @ApiBearerAuth('JWT-auth')
  @ApiOperation({ summary: 'Mendapatkan Group Chat ID berdasarkan Order ID' })
  async getGroupByOrderId(
    @CurrentUser() user: AuthUser,
    @Param('orderId') orderIdParam: string,
    @Query('itemId') itemId?: string,
  ) {
    await this.access.assertOrderAccess(user, orderIdParam);
    return await this.chatService.getGroupByOrderId(orderIdParam, itemId);
  }

  @Post('groups/:groupId/messages')
  @ApiBearerAuth('JWT-auth')
  @ApiOperation({ summary: 'Kirim pesan ke Group Chat (Text / Image / Document / System)' })
  async sendMessage(
    @CurrentUser() user: AuthUser,
    @Param('groupId') groupIdParam: string,
    @Body() dto: SendChatMessageDto,
  ) {
    await this.assertMember(user, groupIdParam);
    // Pengirim selalu identitas dari token, bukan dari body.
    return await this.chatService.sendMessage(groupIdParam, { ...dto, senderId: user.sub });
  }

  @Post('groups/:groupId/read')
  @ApiBearerAuth('JWT-auth')
  @ApiOperation({ summary: 'Tandai semua pesan di group chat sebagai sudah dibaca oleh user' })
  async markRead(@CurrentUser() user: AuthUser, @Param('groupId') groupIdParam: string) {
    await this.assertMember(user, groupIdParam);
    return await this.chatService.markGroupAsRead(groupIdParam, { userId: user.sub }, String(user.sub));
  }

  @Get('groups/:groupId/messages')
  @ApiBearerAuth('JWT-auth')
  @ApiOperation({ summary: 'Mendapatkan riwayat pesan dalam grup chat' })
  async getMessages(@CurrentUser() user: AuthUser, @Param('groupId') groupIdParam: string) {
    await this.assertMember(user, groupIdParam);
    return await this.chatService.getMessages(groupIdParam, String(user.sub));
  }

  @Get('groups/:groupId')
  @ApiBearerAuth('JWT-auth')
  @ApiOperation({ summary: 'Mendapatkan detail grup chat dan anggota' })
  async getGroupDetail(@CurrentUser() user: AuthUser, @Param('groupId') groupIdParam: string) {
    await this.assertMember(user, groupIdParam);
    return await this.chatService.getGroupDetail(groupIdParam, String(user.sub));
  }

  @Get('groups/:groupId/members')
  @ApiBearerAuth('JWT-auth')
  @ApiOperation({ summary: 'Mendapatkan anggota grup chat' })
  async getGroupMembers(@CurrentUser() user: AuthUser, @Param('groupId') groupIdParam: string) {
    await this.assertMember(user, groupIdParam);
    return await this.chatService.getGroupMembers(groupIdParam);
  }

  @Get('user/:userId/groups')
  @ApiBearerAuth('JWT-auth')
  @ApiOperation({ summary: 'Mendapatkan daftar grup chat yang diikuti oleh user' })
  async getUserGroups(@CurrentUser() user: AuthUser, @Param('userId') userIdParam: string) {
    this.access.assertSelf(user, userIdParam);
    return await this.chatService.getUserChatGroups(userIdParam);
  }

  @Get('groups')
  @Roles(...ADMIN_ROLES)
  @ApiBearerAuth('JWT-auth')
  @ApiOperation({ summary: 'Mendapatkan semua grup chat (admin)' })
  async getAllGroups() {
    return await this.chatService.getAllChatGroups();
  }
}
