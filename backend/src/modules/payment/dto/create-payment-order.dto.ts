import { PaymentGateway } from '@prisma/client';
import { IsIn, IsOptional, IsUUID } from 'class-validator';

export class CreatePaymentOrderDto {
  @IsUUID()
  roomId!: string;

  @IsOptional()
  @IsIn([PaymentGateway.VNPAY, PaymentGateway.MOMO])
  gateway?: PaymentGateway;
}
