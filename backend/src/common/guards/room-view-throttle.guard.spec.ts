import { ExecutionContext } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { ThrottlerException, ThrottlerModule } from '@nestjs/throttler';
import { User } from '@prisma/client';
import { RoomViewThrottleGuard } from './room-view-throttle.guard';

const landlord = { id: '3150027c-71b7-4c07-8e54-3d1b61e8cb98' } as User;

const contextFor = (user: User) =>
  ({
    switchToHttp: () => ({ getRequest: () => ({ user }) }),
  }) as unknown as ExecutionContext;

const storageWithHits = (totalHits: number) => ({
  increment: jest.fn().mockResolvedValue({
    totalHits,
    timeToExpire: 42,
    isBlocked: false,
    timeToBlockExpire: 0,
  }),
});

describe('RoomViewThrottleGuard', () => {
  it('counts room views against the authenticated account', async () => {
    const storage = storageWithHits(1);
    const guard = new RoomViewThrottleGuard(storage as never);

    await expect(guard.canActivate(contextFor(landlord))).resolves.toBe(true);
    expect(storage.increment.mock.calls[0][0]).toBe(`room-views:${landlord.id}`);
  });

  it('allows the last view of the window', async () => {
    const guard = new RoomViewThrottleGuard(
      storageWithHits(20) as never,
    );

    await expect(guard.canActivate(contextFor(landlord))).resolves.toBe(true);
  });

  it('rejects one view past the window with 429', async () => {
    const guard = new RoomViewThrottleGuard(
      storageWithHits(21) as never,
    );

    await expect(guard.canActivate(contextFor(landlord))).rejects.toBeInstanceOf(
      ThrottlerException,
    );
  });

  it('resolves the throttler storage through dependency injection', async () => {
    const moduleRef = await Test.createTestingModule({
      imports: [ThrottlerModule.forRoot([{ ttl: 60_000, limit: 100 }])],
      providers: [RoomViewThrottleGuard],
    }).compile();

    expect(moduleRef.get(RoomViewThrottleGuard)).toBeInstanceOf(
      RoomViewThrottleGuard,
    );
  });
});
