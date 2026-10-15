import { Injectable, Logger, ServiceUnavailableException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

export interface OtpSender {
  send(phone: string, otp: string): Promise<void>;
}

@Injectable()
export class DevelopmentOtpSender implements OtpSender {
  private readonly logger = new Logger(DevelopmentOtpSender.name);

  constructor(private readonly config: ConfigService) {}

  async send(phone: string, otp: string): Promise<void> {
    if (this.config.get('NODE_ENV') === 'production') {
      throw new ServiceUnavailableException(
        'SMS provider is not configured for production.',
      );
    }
    this.logger.log(`Development OTP sent to ${phone}: ${otp}`);
  }
}
