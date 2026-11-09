import {
  BadGatewayException,
  Injectable,
  ServiceUnavailableException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { randomUUID } from 'node:crypto';
import {
  HashAlgorithm,
  ProductCode,
  VNPay,
  VnpLocale,
  dateFormat,
  getResponseByStatusCode,
} from 'vnpay';
import type { ReturnQueryFromVNPay, VerifyReturnUrl } from 'vnpay';

@Injectable()
export class VnpayService {
  private cachedClient?: VNPay;
  private readonly queryIp: string;
  private readonly publicApiUrl: string;

  constructor(private readonly config: ConfigService) {
    this.queryIp =
      this.config.get<string>('VNPAY_QUERY_IP_ADDR') ?? '127.0.0.1';
    this.publicApiUrl = (
      this.config.get<string>('PUBLIC_API_URL') ?? 'http://localhost:3000'
    ).replace(/\/+$/, '');
  }

  get returnUrl(): string {
    return `${this.publicApiUrl}/api/payment/vnpay/return`;
  }

  devCheckoutUrl(txnRef: string): string {
    return `${this.publicApiUrl}/api/payment/dev/checkout/${encodeURIComponent(txnRef)}`;
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

  private get hasCredentials(): boolean {
    return Boolean(
      this.config.get<string>('VNPAY_TMN_CODE') &&
        this.config.get<string>('VNPAY_SECURE_SECRET'),
    );
  }

  // Dev stand-ins only exist off production and only until real credentials land.
  get devModeEnabled(): boolean {
    return (
      this.config.get<string>('NODE_ENV') !== 'production' && !this.hasCredentials
    );
  }

  private devMock<T>(response: T): T {
    if (!this.devModeEnabled) {
      throw new ServiceUnavailableException(
        'VNPay merchant credentials are not configured.',
      );
    }
    return response;
  }

  // The portal page is what the shopper actually sees, so the whole signed URL
  // is handed to the app instead of a QR payload.
  buildCheckoutUrl(input: {
    amount: number;
    txnRef: string;
    ip: string;
    createdAt: Date;
    orderInfo: string;
  }): string {
    if (!this.hasCredentials) {
      return this.devMock(this.devCheckoutUrl(input.txnRef));
    }
    return this.client.buildPaymentUrl({
      vnp_Amount: input.amount,
      vnp_TxnRef: input.txnRef,
      vnp_IpAddr: input.ip,
      vnp_OrderInfo: input.orderInfo,
      vnp_OrderType: ProductCode.Other,
      vnp_Locale: VnpLocale.VN,
      vnp_ReturnUrl: this.returnUrl,
      vnp_CreateDate: dateFormat(input.createdAt),
      vnp_ExpireDate: dateFormat(new Date(Date.now() + 15 * 60_000)),
    });
  }

  verifyReturn(query: ReturnQueryFromVNPay): VerifyReturnUrl {
    if (!this.hasCredentials) {
      throw new ServiceUnavailableException(
        'VNPay merchant credentials are not configured.',
      );
    }
    return this.client.verifyReturnUrl(query);
  }

  describeResponse(responseCode?: string): string {
    return getResponseByStatusCode(responseCode, VnpLocale.VN);
  }

  queryStatus(input: {
    txnRef: string;
    createdAt: Date;
    amount: number;
  }) {
    if (!this.hasCredentials) {
      return this.devMock({
        isVerified: true,
        isSuccess: false,
        vnp_TxnRef: input.txnRef,
        vnp_Amount: Math.round(input.amount * 100),
        vnp_ResponseCode: '00',
        vnp_TransactionStatus: '01',
        vnp_TransactionNo: undefined,
        vnp_PayDate: undefined,
      });
    }
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

  // Inverse of parsePaymentDate, so the app can echo the stamp VNPay itself shows.
  formatPaymentDate(value: Date): string {
    const gmt7 = new Date(value.getTime() + 7 * 3600_000);
    const pad = (part: number) => String(part).padStart(2, '0');
    return [
      gmt7.getUTCFullYear(),
      pad(gmt7.getUTCMonth() + 1),
      pad(gmt7.getUTCDate()),
      pad(gmt7.getUTCHours()),
      pad(gmt7.getUTCMinutes()),
      pad(gmt7.getUTCSeconds()),
    ].join('');
  }
}
