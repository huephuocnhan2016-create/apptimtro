import { Body, Controller, Get, Post, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { User } from '@prisma/client';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { ChatConversationThrottleGuard } from '../../common/guards/chat-conversation-throttle.guard';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { CreateConversationDto } from './dto/create-conversation.dto';
import { ChatService } from './chat.service';

@ApiTags('Chat')
@Controller('chat')
export class ChatController {
  constructor(private readonly chat: ChatService) {}

  @Get('conversations')
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard)
  @ApiOperation({ summary: 'Danh sách cuộc trò chuyện của người đang đăng nhập' })
  listConversations(@CurrentUser() user: User) {
    return this.chat.listConversations(user);
  }

  @Post('conversations')
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard, ChatConversationThrottleGuard)
  @ApiOperation({ summary: 'Mở (hoặc lấy) hội thoại với chủ trọ của một phòng' })
  openConversation(@CurrentUser() user: User, @Body() dto: CreateConversationDto) {
    return this.chat.openConversation(user, dto);
  }
}
