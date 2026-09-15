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
import { SendChatMessageDto } from '../../orders.dto';
import { ChatService } from './chat.service';

@ApiTags('Group Chat')
@Controller('chat')
export class ChatController {
  constructor(private readonly chatService: ChatService) {}

  @Get('order/:orderId')
  @ApiBearerAuth('JWT-auth')
  @ApiOperation({ summary: 'Mendapatkan Group Chat ID berdasarkan Order ID' })
  async getGroupByOrderId(@Param('orderId') orderIdParam: string) {
    return await this.chatService.getGroupByOrderId(orderIdParam);
  }

  @Post('groups/:groupId/messages')
  @ApiBearerAuth('JWT-auth')
  @ApiOperation({ summary: 'Kirim pesan ke Group Chat (Text / Image / Document / System)' })
  async sendMessage(
    @Param('groupId') groupIdParam: string,
    @Body() dto: SendChatMessageDto,
  ) {
    return await this.chatService.sendMessage(groupIdParam, dto);
  }

  @Post('groups/:groupId/read')
  @ApiBearerAuth('JWT-auth')
  @ApiOperation({ summary: 'Tandai semua pesan di group chat sebagai sudah dibaca oleh user' })
  async markRead(
    @Param('groupId') groupIdParam: string,
    @Body() body: { userId?: number },
    @Query('userId') queryUserId?: string,
  ) {
    return await this.chatService.markGroupAsRead(groupIdParam, body, queryUserId);
  }

  @Get('groups/:groupId/messages')
  @ApiBearerAuth('JWT-auth')
  @ApiOperation({ summary: 'Mendapatkan riwayat pesan dalam grup chat' })
  async getMessages(
    @Param('groupId') groupIdParam: string,
    @Query('userId') userIdParam?: string,
  ) {
    return await this.chatService.getMessages(groupIdParam, userIdParam);
  }

  @Get('groups/:groupId')
  @ApiBearerAuth('JWT-auth')
  @ApiOperation({ summary: 'Mendapatkan detail grup chat dan anggota' })
  async getGroupDetail(
    @Param('groupId') groupIdParam: string,
    @Query('userId') queryUserId?: string,
  ) {
    return await this.chatService.getGroupDetail(groupIdParam, queryUserId);
  }

  @Get('groups/:groupId/members')
  @ApiBearerAuth('JWT-auth')
  @ApiOperation({ summary: 'Mendapatkan anggota grup chat' })
  async getGroupMembers(@Param('groupId') groupIdParam: string) {
    return await this.chatService.getGroupMembers(groupIdParam);
  }

  @Get('user/:userId/groups')
  @ApiBearerAuth('JWT-auth')
  @ApiOperation({ summary: 'Mendapatkan daftar grup chat yang diikuti oleh user' })
  async getUserGroups(@Param('userId') userIdParam: string) {
    return await this.chatService.getUserChatGroups(userIdParam);
  }

  @Get('groups')
  @ApiBearerAuth('JWT-auth')
  @ApiOperation({ summary: 'Mendapatkan semua grup chat' })
  async getAllGroups() {
    return await this.chatService.getAllChatGroups();
  }
}
