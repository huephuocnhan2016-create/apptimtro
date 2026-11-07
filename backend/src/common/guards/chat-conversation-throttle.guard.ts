import {
  CanActivate,
  ExecutionContext,
  Inject,
  Injectable,
} from '@nestjs/common';
import { ThrottlerException, ThrottlerStorage } from '@nestjs/throttler';
import { AuthenticatedRequest } from '../decorators/current-user.decorator';

const WINDOW_MS = 60_000;
const CHAT_CONVERSATIONS_PER_WINDOW = 20;

@Injectable()
export class ChatConversationThrottleGuard implements CanActivate {
  constructor(@Inject(ThrottlerStorage) private readonly storage: ThrottlerStorage) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const { user } = context.switchToHttp().getRequest<AuthenticatedRequest>();
    const { totalHits, timeToExpire } = await this.storage.increment(
      `chat-conversations:${user.id}`,
      WINDOW_MS,
      CHAT_CONVERSATIONS_PER_WINDOW,
      0,
      'chat-conversations',
    );
    if (totalHits > CHAT_CONVERSATIONS_PER_WINDOW) {
      throw new ThrottlerException(
        `Chat conversations are limited to ${CHAT_CONVERSATIONS_PER_WINDOW} openings per minute. Try again in ${timeToExpire} seconds.`,
      );
    }
    return true;
  }
}
