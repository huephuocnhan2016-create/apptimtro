import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { PassportModule } from '@nestjs/passport';
import { AuthController } from './auth.controller';
import { AuthService, DevelopmentOtpSender, OTP_SENDER } from './auth.service';
import { FirebaseTokenService } from './firebase-token.service';
import { JwtStrategy } from './jwt.strategy';

@Module({
  imports: [JwtModule.register({}), PassportModule.register({ defaultStrategy: 'jwt' })],
  controllers: [AuthController],
  providers: [
    AuthService,
    FirebaseTokenService,
    JwtStrategy,
    DevelopmentOtpSender,
    { provide: OTP_SENDER, useExisting: DevelopmentOtpSender },
  ],
  exports: [AuthService],
})
export class AuthModule {}
