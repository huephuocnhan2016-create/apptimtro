import { BadGatewayException, Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { randomUUID } from 'node:crypto';
import { HashAlgorithm, VNPay, dateFormat, parseDate } from 'vnpay';

@Injectable()
export class VnpayService {
  private readonly client: VNPay;
  private readonly queryIp: string;

  constructor(config: ConfigService) {
    this.queryIp = config.getOrThrow<string>('VNPAY_QUERY_IP_ADDR');
    this.client = new VNPay({
      tmnCode: config.getOrThrow<string>('VNPAY_TMN_CODE'),
      secureSecret: config.getOrThrow<string>('VNPAY_SECURE_SECRET'),
      vnpayHost: 'https://sandbox.vnpayment.vn',
      testMode: true,
      hashAlgorithm: config.getOrThrow<HashAlgorithm>('VNPAY_HASH_ALGORITHM'),
      enableLog: false,
    });
  }

  async createQr(input: {
    amount: number;
    txnRef: string;
    ip: string;
    createdAt: Date;
  }) {
    const result = await this.client.generateQr({
      vnp_Amount: input.amount,
      vnp_TxnRef: input.txnRef,
      vnp_IpAddr: input.ip,
      vnp_OrderInfo: `Tro Tot ${input.txnRef}`,
      vnp_CreateDate: dateFormat(input.createdAt),
      vnp_ExpireDate: dateFormat(new Date(Date.now() + 15 * 60_000)),
      // Required by the SDK request type but unused by genqr.
      vnp_ReturnUrl: 'https://localhost',
    });
    if (result.code !== '00' || !result.qrcontent) {
      throw new BadGatewayException('VNPay did not return a valid QR code.');
    }
    return result;
  }

  queryStatus(input: {
    txnRef: string;
    createdAt: Date;
  }) {
    const paymentDate = dateFormat(input.createdAt);
    const request = {
      vnp_RequestId: randomUUID().replace(/-/g, ''),
      vnp_TxnRef: input.txnRef,
      vnp_TransactionDate: paymentDate,
      vnp_CreateDate: dateFormat(new Date()),
      vnp_IpAddr: this.queryIp,
      vnp_OrderInfo: `Tro Tot ${input.txnRef}`,
    } satisfies Omit<Parameters<VNPay['queryDr']>[0], 'vnp_TransactionNo'>;
    // The SDK marks this field required, but VNPay's querydr API makes it optional.
    return this.client.queryDr(
      request as Parameters<VNPay['queryDr']>[0],
    );
  }

  parsePaymentDate(value: string | number): Date {
    return parseDate(value, 'gmt7');
  }
}
