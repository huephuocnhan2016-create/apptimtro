import { PaymentStatus } from '@prisma/client';

export class PaymentOrderEntity {
  constructor(
    readonly txnRef: string,
    readonly qrcontent: string,
    readonly amount: number,
    readonly status: PaymentStatus,
  ) {}
}
