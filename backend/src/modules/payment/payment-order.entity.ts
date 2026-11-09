import { PaymentGateway, PaymentStatus } from '@prisma/client';

export class PaymentOrderEntity {
  constructor(
    readonly txnRef: string,
    readonly payUrl: string,
    readonly amount: number,
    readonly status: PaymentStatus,
    readonly orderInfo: string,
    readonly gateway: PaymentGateway,
    // MoMo also hands back a wallet deep link and a QR image, which is what
    // the app opens instead of the web page when it can.
    readonly deeplink: string | null = null,
    readonly qrCodeUrl: string | null = null,
  ) {}
}
