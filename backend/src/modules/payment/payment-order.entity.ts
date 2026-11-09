import { PaymentStatus } from '@prisma/client';

export class PaymentOrderEntity {
  constructor(
    readonly txnRef: string,
    readonly payUrl: string,
    readonly amount: number,
    readonly status: PaymentStatus,
    readonly orderInfo: string,
  ) {}
}
