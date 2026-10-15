import {
  ConflictException,
  Inject,
  Injectable,
  Logger,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { Prisma, User, UserRole } from '@prisma/client';
import {
  createHash,
  createHmac,
  randomBytes,
  randomInt,
  timingSafeEqual,
} from 'node:crypto';
import { PrismaService } from '../../database/prisma.service';
import { LoginDto } from './dto/login.dto';
import { RegisterDto } from './dto/register.dto';
import { normalizeVietnamesePhone } from './phone.util';
import { DevelopmentOtpSender, OtpSender } from './otp-sender';

const OTP_SENDER = 'OTP_SENDER';

interface VerificationPayload {
  sub: string;
  phone: string;
  role: UserRole;
  tokenType: 'verification';
}

export interface TokenPair {
  accessToken: string;
  refreshToken: string;
  user: ReturnType<AuthService['serializeUser']>;
}

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly jwt: JwtService,
    private readonly config: ConfigService,
    @Inject(OTP_SENDER) private readonly otpSender: OtpSender,
  ) {}

  async sendOtp(phoneInput: string, role: UserRole): Promise<{
    phone: string;
    expiresInSeconds: number;
    devOtp?: string;
  }> {
    const phone = normalizeVietnamesePhone(phoneInput);
    const otp = randomInt(0, 1_000_000).toString().padStart(6, '0');
    const ttlMinutes = this.config.getOrThrow<number>('OTP_TTL_MINUTES');
    const now = new Date();

    await this.prisma.$transaction([
      this.prisma.phoneVerification.updateMany({
        where: { phone, consumedAt: null },
        data: { consumedAt: now },
      }),
      this.prisma.phoneVerification.create({
        data: {
          phone,
          role,
          otpHash: this.hashOtp(phone, otp),
          expiresAt: new Date(now.getTime() + ttlMinutes * 60_000),
        },
      }),
    ]);

    const devOtpEnabled = this.config.getOrThrow<boolean>('DEV_OTP_ENABLED');
    if (!devOtpEnabled) await this.otpSender.send(phone, otp);

    return {
      phone,
      expiresInSeconds: ttlMinutes * 60,
      ...(devOtpEnabled && this.config.get('NODE_ENV') !== 'production'
        ? { devOtp: otp }
        : {}),
    };
  }

  async verifyOtp(phoneInput: string, otp: string): Promise<{
    verificationToken: string;
    expiresInSeconds: number;
  }> {
    const phone = normalizeVietnamesePhone(phoneInput);
    const verification = await this.prisma.phoneVerification.findFirst({
      where: { phone, consumedAt: null },
      orderBy: { createdAt: 'desc' },
    });
    if (
      !verification ||
      verification.expiresAt <= new Date() ||
      verification.attempts >= 5
    ) {
      throw new UnauthorizedException('OTP is invalid or has expired.');
    }

    const actualHash = Buffer.from(this.hashOtp(phone, otp), 'hex');
    const expectedHash = Buffer.from(verification.otpHash, 'hex');
    const valid =
      actualHash.length === expectedHash.length &&
      timingSafeEqual(actualHash, expectedHash);
    if (!valid) {
      await this.prisma.phoneVerification.updateMany({
        where: {
          id: verification.id,
          consumedAt: null,
          attempts: { lt: 5 },
        },
        data: { attempts: { increment: 1 } },
      });
      throw new UnauthorizedException('OTP is invalid or has expired.');
    }

    const now = new Date();
    const updated = await this.prisma.phoneVerification.updateMany({
      where: {
        id: verification.id,
        consumedAt: null,
        verifiedAt: null,
        expiresAt: { gt: now },
        attempts: { lt: 5 },
      },
      data: { verifiedAt: now },
    });
    if (updated.count !== 1) {
      throw new UnauthorizedException('OTP is invalid or has expired.');
    }

    const expiresInSeconds =
      this.config.getOrThrow<number>('OTP_TTL_MINUTES') * 60;
    const verificationToken = await this.jwt.signAsync(
      {
        sub: verification.id,
        phone,
        role: verification.role,
        tokenType: 'verification',
      } satisfies VerificationPayload,
      {
        secret: this.config.getOrThrow<string>('OTP_SECRET'),
        expiresIn: expiresInSeconds,
      },
    );
    return { verificationToken, expiresInSeconds };
  }

  async register(dto: RegisterDto): Promise<TokenPair> {
    if (dto.role === UserRole.ADMIN) {
      throw new UnauthorizedException('Admin accounts cannot self-register.');
    }
    const phone = normalizeVietnamesePhone(dto.phone);
    try {
      const user = await this.prisma.$transaction(async (transaction) => {
        await this.consumeVerification(
          transaction,
          dto.verificationToken,
          phone,
          dto.role,
        );
        return transaction.user.create({
          data: {
            phone,
            role: dto.role,
            fullName: dto.fullName.trim(),
            email: dto.email?.trim().toLowerCase(),
            isVerified: true,
          },
        });
      });
      return this.createSession(user);
    } catch (error) {
      if (this.isUniqueConstraintError(error)) {
        throw new ConflictException('An account with this phone or email exists.');
      }
      throw error;
    }
  }

  async login(dto: LoginDto): Promise<TokenPair> {
    const phone = normalizeVietnamesePhone(dto.phone);
    const user = await this.prisma.$transaction(async (transaction) => {
      await this.consumeVerification(
        transaction,
        dto.verificationToken,
        phone,
      );
      const account = await transaction.user.findUnique({ where: { phone } });
      if (!account || !account.isVerified) {
        throw new UnauthorizedException('No verified account exists for this phone.');
      }
      return account;
    });
    return this.createSession(user);
  }

  async refresh(refreshToken: string): Promise<TokenPair> {
    const tokenHash = this.hashRefreshToken(refreshToken);
    const stored = await this.prisma.refreshToken.findUnique({
      where: { tokenHash },
      include: { user: true },
    });
    if (!stored) throw new UnauthorizedException('Refresh token is invalid.');
    if (stored.revokedAt) {
      await this.prisma.refreshToken.updateMany({
        where: { userId: stored.userId, revokedAt: null },
        data: { revokedAt: new Date() },
      });
      throw new UnauthorizedException('Refresh token reuse detected.');
    }
    if (stored.expiresAt <= new Date()) {
      throw new UnauthorizedException('Refresh token has expired.');
    }

    const nextToken = randomBytes(32).toString('base64url');
    const nextExpiresAt = this.refreshExpiry();
    const rotated = await this.prisma.$transaction(async (transaction) => {
      const revoked = await transaction.refreshToken.updateMany({
        where: { id: stored.id, revokedAt: null, expiresAt: { gt: new Date() } },
        data: { revokedAt: new Date() },
      });
      if (revoked.count !== 1) {
        throw new UnauthorizedException('Refresh token is no longer valid.');
      }
      await transaction.refreshToken.create({
        data: {
          tokenHash: this.hashRefreshToken(nextToken),
          userId: stored.userId,
          expiresAt: nextExpiresAt,
        },
      });
      return stored.user;
    });
    return this.createSession(rotated, nextToken, nextExpiresAt);
  }

  async logout(userId: string): Promise<void> {
    await this.prisma.refreshToken.updateMany({
      where: { userId, revokedAt: null },
      data: { revokedAt: new Date() },
    });
  }

  async me(userId: string): Promise<ReturnType<AuthService['serializeUser']>> {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) throw new UnauthorizedException('Account no longer exists.');
    return this.serializeUser(user);
  }

  serializeUser(user: User) {
    return {
      id: user.id,
      phone: user.phone,
      email: user.email,
      fullName: user.fullName,
      avatarUrl: user.avatarUrl,
      role: user.role,
      isVerified: user.isVerified,
      createdAt: user.createdAt,
      updatedAt: user.updatedAt,
    };
  }

  private async consumeVerification(
    transaction: Prisma.TransactionClient,
    token: string,
    phone: string,
    requiredRole?: UserRole,
  ): Promise<void> {
    let payload: VerificationPayload;
    try {
      payload = await this.jwt.verifyAsync<VerificationPayload>(token, {
        secret: this.config.getOrThrow<string>('OTP_SECRET'),
      });
    } catch {
      throw new UnauthorizedException('Phone verification is invalid or expired.');
    }
    if (
      payload.tokenType !== 'verification' ||
      payload.phone !== phone ||
      (requiredRole !== undefined && payload.role !== requiredRole)
    ) {
      throw new UnauthorizedException('Phone verification is invalid or expired.');
    }

    const now = new Date();
    const used = await transaction.phoneVerification.updateMany({
      where: {
        id: payload.sub,
        phone,
        verifiedAt: { not: null },
        consumedAt: null,
        expiresAt: { gt: now },
      },
      data: { consumedAt: now },
    });
    if (used.count !== 1) {
      throw new UnauthorizedException('Phone verification is invalid or expired.');
    }
  }

  private async createSession(
    user: User,
    refreshToken = randomBytes(32).toString('base64url'),
    expiresAt = this.refreshExpiry(),
  ): Promise<TokenPair> {
    const accessToken = await this.jwt.signAsync(
      { sub: user.id, role: user.role, tokenType: 'access' },
      {
        secret: this.config.getOrThrow<string>('JWT_ACCESS_SECRET'),
        expiresIn: this.config.getOrThrow<number>('ACCESS_TOKEN_SECONDS'),
      },
    );
    await this.prisma.refreshToken.create({
      data: {
        tokenHash: this.hashRefreshToken(refreshToken),
        userId: user.id,
        expiresAt,
      },
    });
    return {
      accessToken,
      refreshToken,
      user: this.serializeUser(user),
    };
  }

  private refreshExpiry(): Date {
    return new Date(
      Date.now() +
        this.config.getOrThrow<number>('REFRESH_TOKEN_DAYS') * 86_400_000,
    );
  }

  private hashRefreshToken(token: string): string {
    return createHash('sha256').update(token).digest('hex');
  }

  private hashOtp(phone: string, otp: string): string {
    return createHmac('sha256', this.config.getOrThrow<string>('OTP_SECRET'))
      .update(`${phone}:${otp}`)
      .digest('hex');
  }

  private isUniqueConstraintError(
    error: unknown,
  ): error is Prisma.PrismaClientKnownRequestError {
    return (
      error instanceof Prisma.PrismaClientKnownRequestError &&
      error.code === 'P2002'
    );
  }
}

export { OTP_SENDER, DevelopmentOtpSender };
