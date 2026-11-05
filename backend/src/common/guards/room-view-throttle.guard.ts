import {
  CanActivate,
  ExecutionContext,
  Inject,
  Injectable,
} from '@nestjs/common';
import { ThrottlerException, ThrottlerStorage } from '@nestjs/throttler';
import { AuthenticatedRequest } from '../decorators/current-user.decorator';

const WINDOW_MS = 60_000;
const ROOM_VIEWS_PER_WINDOW = 20;

@Injectable()
export class RoomViewThrottleGuard implements CanActivate {
  constructor(@Inject(ThrottlerStorage) private readonly storage: ThrottlerStorage) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const { user } = context.switchToHttp().getRequest<AuthenticatedRequest>();
    const { totalHits, timeToExpire } = await this.storage.increment(
      `room-views:${user.id}`,
      WINDOW_MS,
      ROOM_VIEWS_PER_WINDOW,
      0,
      'room-views',
    );
    if (totalHits > ROOM_VIEWS_PER_WINDOW) {
      throw new ThrottlerException(
        `Room details are limited to ${ROOM_VIEWS_PER_WINDOW} views per minute. Try again in ${timeToExpire} seconds.`,
      );
    }
    return true;
  }
}
