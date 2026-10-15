import { UnauthorizedException } from '@nestjs/common';
import { UserRole } from '@prisma/client';
import { AuthService } from './auth.service';
import { PrismaService } from '../../database/prisma.service';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { OtpSender } from './otp-sender';

describe('AuthService OTP protections', () => {
  const prisma = {
    phoneVerification: {
      updateMany: jest.fn().mockResolvedValue({ count: 1 }),
      create: jest.fn().mockResolvedValue({}),
      findFirst: jest.fn(),
    },
    $transaction: jest.fn((operations: Promise<unknown>[]) =>
      Promise.all(operations),
    ),
  };
  const jwt = { signAsync: jest.fn(), verifyAsync: jest.fn() };
  const config = {
    getOrThrow: jest.fn((key: string) => {
      const values: Record<string, unknown> = {
        OTP_TTL_MINUTES: 5,
        OTP_SECRET: 'otp-secret-for-unit-testing',
        DEV_OTP_ENABLED: true,
      };
      return values[key];
    }),
    get: jest.fn(() => 'test'),
  };
  const sender = { send: jest.fn() };
  const auth = new AuthService(
    prisma as unknown as PrismaService,
    jwt as unknown as JwtService,
    config as unknown as ConfigService,
    sender as unknown as OtpSender,
  );

  beforeEach(() => jest.clearAllMocks());

  it('creates a single-use OTP challenge without sending SMS in development', async () => {
    const response = await auth.sendOtp('0901234567', UserRole.STUDENT);

    expect(response.phone).toBe('+84901234567');
    expect(response.devOtp).toMatch(/^\d{6}$/);
    expect(prisma.phoneVerification.create.mock.calls[0][0].data.otpHash)
      .not.toBe(response.devOtp);
    expect(sender.send).not.toHaveBeenCalled();
  });

  it('rejects OTP challenges that have exceeded the attempt limit', async () => {
    prisma.phoneVerification.findFirst.mockResolvedValue({
      id: 'challenge-id',
      phone: '+84901234567',
      otpHash: '0'.repeat(64),
      expiresAt: new Date(Date.now() + 60_000),
      attempts: 5,
      consumedAt: null,
    });

    await expect(auth.verifyOtp('0901234567', '123456'))
      .rejects.toBeInstanceOf(UnauthorizedException);
  });
});
