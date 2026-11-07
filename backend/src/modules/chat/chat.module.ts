import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { ChatConversationThrottleGuard } from '../../common/guards/chat-conversation-throttle.guard';
import { ChatController } from './chat.controller';
import { ChatService } from './chat.service';

@Module({
  imports: [AuthModule],
  controllers: [ChatController],
  providers: [ChatService, ChatConversationThrottleGuard],
  exports: [ChatService],
})
export class ChatModule {}
