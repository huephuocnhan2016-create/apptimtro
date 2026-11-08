import {
  BadGatewayException,
  Injectable,
  ServiceUnavailableException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { randomUUID } from 'node:crypto';
import { HashAlgorithm, VNPay, dateFormat } from 'vnpay';

@Injectable()
export class VnpayService {
  private cachedClient?: VNPay;
  private readonly queryIp: string;

  constructor(private readonly config: ConfigService) {
    this.queryIp =
      this.config.get<string>('VNPAY_QUERY_IP_ADDR') ?? '127.0.0.1';
  }

  // Built on first use so a machine without merchant credentials still boots.
  private get client(): VNPay {
    if (this.cachedClient) {
      return this.cachedClient;
    }
    const tmnCode = this.config.get<string>('VNPAY_TMN_CODE');
    const secureSecret = this.config.get<string>('VNPAY_SECURE_SECRET');
    if (!tmnCode || !secureSecret) {
      throw new ServiceUnavailableException(
        'VNPay merchant credentials are not configured.',
      );
    }
    this.cachedClient = new VNPay({
      tmnCode,
      secureSecret,
      vnpayHost: 'https://sandbox.vnpayment.vn',
      testMode: true,
      hashAlgorithm:
        this.config.get<HashAlgorithm>('VNPAY_HASH_ALGORITHM') ??
        HashAlgorithm.SHA512,
      enableLog: false,
    });
    return this.cachedClient;
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
    const digits = String(value);
    if (!/^\d{14}$/.test(digits)) {
      throw new BadGatewayException('VNPay returned an invalid payment date.');
    }
    // vnp_PayDate is wall-clock GMT+7, so the instant is seven hours earlier.
    return new Date(
      Date.UTC(
        Number(digits.slice(0, 4)),
        Number(digits.slice(4, 6)) - 1,
        Number(digits.slice(6, 8)),
        Number(digits.slice(8, 10)) - 7,
        Number(digits.slice(10, 12)),
        Number(digits.slice(12, 14)),
      ),
    );
  }
}
