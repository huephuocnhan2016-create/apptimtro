import { IsUUID } from 'class-validator';

export class CreatePaymentOrderDto {
  @IsUUID()
  roomId!: string;
}
