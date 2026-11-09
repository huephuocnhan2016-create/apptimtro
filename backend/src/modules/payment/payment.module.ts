import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { MomoService } from './momo.service';
import { PaymentController } from './payment.controller';
import { PaymentService } from './payment.service';
import { VnpayService } from './vnpay.service';

@Module({
  imports: [AuthModule],
  controllers: [PaymentController],
  providers: [PaymentService, VnpayService, MomoService],
  exports: [PaymentService],
})
export class PaymentModule {}
