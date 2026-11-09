import {
  BadGatewayException,
  Injectable,
  ServiceUnavailableException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createHmac, timingSafeEqual } from 'node:crypto';

export type MomoOrderResult = {
  isVerified: boolean;
  isSuccess: boolean;
  orderId: string;
  amount: number;
  responseCode: string;
  transactionNo: string | null;
  payDate: Date | null;
  message: string;
};

export type MomoCheckout = {
  payUrl: string;
  deeplink: string | null;
  qrCodeUrl: string | null;
};

// MoMo's own result table, in the Vietnamese wording the sample app shows.
// The deposit stores VNPay-shaped codes, so '00' and '24' are aliased below.
const MOMO_RESULT_MESSAGES: Record<string, string> = {
  '0': 'Thành công.',
  '10': 'Hệ thống đang được bảo trì.',
  '11': 'Truy cập bị từ chối.',
  '12': 'Phiên bản API không được hỗ trợ.',
  '13': 'Xác thực doanh nghiệp thất bại.',
  '20': 'Yêu cầu sai định dạng.',
  '21': 'Số tiền giao dịch không hợp lệ.',
  '22': 'Số tiền giao dịch không hợp lệ.',
  '40': 'RequestId bị trùng.',
  '41': 'OrderId bị trùng.',
  '42': 'OrderId không hợp lệ hoặc không tìm thấy.',
  '98': 'QR Code tạo không thành công.',
  '99': 'Lỗi không xác định.',
  '1000': 'Giao dịch đã khởi tạo, chờ xác nhận.',
  '1001': 'Giao dịch thất bại do không đủ tiền.',
  '1002': 'Giao dịch bị từ chối bởi nhà phát hành.',
  '1003': 'Giao dịch đã bị hủy.',
  '1004': 'Giao dịch thất bại do vượt quá hạn mức.',
  '1005': 'Giao dịch thất bại do URL/QR hết hạn.',
  '1006': 'Người dùng từ chối xác nhận.',
  '7000': 'Giao dịch đang được xử lý.',
  '9000': 'Giao dịch được xác nhận thành công.',
};

// MoMo answers with its own result codes while the deposit table has always
// stored VNPay-shaped ones, and close()/markClosed() branch on '00' and '24'.
// Translating here keeps one mapping for both portals instead of teaching the
// order state machine about two payment schemes.
const CANCELLED_MOMO_CODES = new Set(['1004', '1005', '1102', '1103']);

const REQUEST_TIMEOUT_MS = 10_000;

@Injectable()
export class MomoService {
  private readonly publicApiUrl: string;

  constructor(private readonly config: ConfigService) {
    this.publicApiUrl = (
      this.config.get<string>('PUBLIC_API_URL') ?? 'http://localhost:3000'
    ).replace(/\/+$/, '');
  }

  get hasCredentials(): boolean {
    return Boolean(
      this.partnerCode && this.accessKey && this.secretKey,
    );
  }

  get devModeEnabled(): boolean {
    return (
      this.config.get<string>('NODE_ENV') !== 'production' &&
      !this.hasCredentials
    );
  }

  devCheckoutUrl(txnRef: string): string {
    return `${this.publicApiUrl}/api/payment/dev/checkout/${encodeURIComponent(txnRef)}`;
  }

  private get returnUrl(): string {
    return (
      this.config.get<string>('MOMO_RETURN_URL') ||
      `${this.publicApiUrl}/api/payment/momo/return`
    );
  }

  private get ipnUrl(): string {
    return (
      this.config.get<string>('MOMO_IPN_URL') ||
      `${this.publicApiUrl}/api/payment/momo/ipn`
    );
  }

  private get endpoint(): string {
    return (
      this.config.get<string>('MOMO_ENDPOINT') || 'https://test-payment.momo.vn'
    ).replace(/\/+$/, '');
  }

  private get partnerCode(): string {
    return this.config.get<string>('MOMO_PARTNER_CODE') ?? '';
  }

  private get accessKey(): string {
    return this.config.get<string>('MOMO_ACCESS_KEY') ?? '';
  }

  private get secretKey(): string {
    return this.config.get<string>('MOMO_SECRET_KEY') ?? '';
  }

  private get requestType(): string {
    return this.config.get<string>('MOMO_REQUEST_TYPE') || 'payWithApp';
  }

  // MoMo signs a fixed field order of raw "k=v" pairs joined with '&'. Values
  // go in unencoded, and a missing value still contributes "k=".
  private sign(pairs: [string, string | number][]): string {
    const raw = pairs
      .map(([key, value]) => `${key}=${value ?? ''}`)
      .join('&');
    return createHmac('sha256', this.secretKey).update(raw, 'utf8').digest('hex');
  }

  private matches(expected: string, received: string | undefined): boolean {
    if (!received) return false;
    const left = Buffer.from(expected, 'utf8');
    const right = Buffer.from(received, 'utf8');
    return left.length === right.length && timingSafeEqual(left, right);
  }

  async createOrder(input: {
    amount: number;
    orderId: string;
    orderInfo: string;
    requestId: string;
  }): Promise<MomoCheckout> {
    if (!this.hasCredentials) {
      this.assertDevMode();
      return {
        payUrl: this.devCheckoutUrl(input.orderId),
        deeplink: null,
        qrCodeUrl: null,
      };
    }

    const body: Record<string, string | number> = {
      partnerCode: this.partnerCode,
      accessKey: this.accessKey,
      requestId: input.requestId,
      amount: input.amount,
      orderId: input.orderId,
      orderInfo: input.orderInfo,
      redirectUrl: this.returnUrl,
      ipnUrl: this.ipnUrl,
      extraData: '',
      requestType: this.requestType,
      lang: 'vi',
    };
    body.signature = this.sign([
      ['accessKey', this.accessKey],
      ['amount', input.amount],
      ['extraData', ''],
      ['ipnUrl', this.ipnUrl],
      ['orderId', input.orderId],
      ['orderInfo', input.orderInfo],
      ['partnerCode', this.partnerCode],
      ['redirectUrl', this.returnUrl],
      ['requestId', input.requestId],
      ['requestType', this.requestType],
    ]);

    const response = await this.post(`${this.endpoint}/v2/gateway/api/create`, body);
    const resultCode = String(response.resultCode ?? '');
    if (resultCode !== '0') {
      throw new BadGatewayException(
        `MoMo refused the order: ${String(response.message ?? resultCode)}`,
      );
    }
    // The field carrying the portal link is not stable across MoMo revisions.
    const payUrl = String(response.payUrl ?? response.url ?? '');
    if (!payUrl) {
      throw new BadGatewayException('MoMo returned no payment URL.');
    }
    return {
      payUrl,
      deeplink: String(response.deeplink ?? response.deepLink ?? '') || null,
      qrCodeUrl: String(response.qrCodeUrl ?? '') || null,
    };
  }

  async queryOrder(input: {
    orderId: string;
    requestId: string;
  }): Promise<MomoOrderResult> {
    if (!this.hasCredentials) {
      this.assertDevMode();
      return this.pendingResult(input.orderId, 0);
    }

    const body: Record<string, string> = {
      partnerCode: this.partnerCode,
      requestId: input.requestId,
      orderId: input.orderId,
      lang: 'vi',
    };
    body.signature = this.sign([
      ['accessKey', this.accessKey],
      ['orderId', input.orderId],
      ['partnerCode', this.partnerCode],
      ['requestId', input.requestId],
    ]);

    const response = await this.post(`${this.endpoint}/v2/gateway/api/query`, body);
    if (
      response.signature !== undefined &&
      !this.matches(this.signResponse(response), String(response.signature))
    ) {
      return { ...this.pendingResult(input.orderId, 0), isVerified: false };
    }
    return this.toResult(response, input.orderId);
  }

  // The browser redirect and the server-to-server IPN carry the same fields;
  // only the transport differs, so both land here.
  parseResult(
    params: Record<string, string>,
  ): MomoOrderResult & { isVerified: boolean } {
    if (!this.hasCredentials) {
      throw new ServiceUnavailableException(
        'MoMo merchant credentials are not configured.',
      );
    }
    const verified = this.matches(
      this.signResult(params),
      params.signature,
    );
    const result = this.toResult(params, params.orderId ?? '');
    return { ...result, isVerified: verified && result.isVerified };
  }

  describeResult(responseCode: string): string {
    if (responseCode === '00') return MOMO_RESULT_MESSAGES['0'];
    if (responseCode === '24') return MOMO_RESULT_MESSAGES['1003'];
    return (
      MOMO_RESULT_MESSAGES[responseCode] ?? `MoMo trả về mã ${responseCode}`
    );
  }

  private toResult(
    data: Record<string, unknown>,
    orderId: string,
  ): MomoOrderResult {
    const rawCode = String(data.resultCode ?? '');
    const amount = Number(data.amount ?? 0);
    // transId is the portal's own transaction number, what a refund would cite.
    const transactionNo =
      String(data.transId ?? data.transactionNo ?? '') || null;
    const responseTime = Number(data.responseTime ?? 0);
    return {
      isVerified: true,
      isSuccess: rawCode === '0',
      orderId: String(data.orderId ?? orderId),
      amount,
      responseCode: this.normalizeCode(rawCode),
      transactionNo,
      payDate: responseTime > 0 ? new Date(responseTime) : null,
      message: String(data.message ?? ''),
    };
  }

  private pendingResult(orderId: string, amount: number): MomoOrderResult {
    return {
      isVerified: true,
      isSuccess: false,
      orderId,
      amount,
      responseCode: '',
      transactionNo: null,
      payDate: null,
      message: 'Giao dịch chưa hoàn tất',
    };
  }

  private normalizeCode(resultCode: string): string {
    if (resultCode === '0') return '00';
    if (CANCELLED_MOMO_CODES.has(resultCode)) return '24';
    return resultCode;
  }

  private signResponse(data: Record<string, unknown>): string {
    return this.sign([
      ['partnerCode', this.partnerCode],
      ['accessKey', this.accessKey],
      ['requestId', String(data.requestId ?? '')],
      ['orderId', String(data.orderId ?? '')],
      ['errorCode', String(data.errorCode ?? '')],
      ['transId', String(data.transId ?? '')],
      ['amount', String(data.amount ?? '')],
      ['message', String(data.message ?? '')],
      ['localMessage', String(data.localMessage ?? '')],
      ['requestType', String(data.requestType ?? '')],
      ['payType', String(data.payType ?? '')],
      ['extraData', String(data.extraData ?? '')],
    ]);
  }

  private signResult(data: Record<string, string>): string {
    return this.sign([
      ['accessKey', this.accessKey],
      ['amount', data.amount ?? ''],
      ['extraData', data.extraData ?? ''],
      ['message', data.message ?? ''],
      ['orderId', data.orderId ?? ''],
      ['orderInfo', data.orderInfo ?? ''],
      ['orderType', data.orderType ?? ''],
      ['partnerCode', this.partnerCode],
      ['payType', data.payType ?? ''],
      ['requestId', data.requestId ?? ''],
      ['responseTime', data.responseTime ?? data.timestamp ?? ''],
      ['resultCode', data.resultCode ?? ''],
      ['transId', data.transId ?? data.transactionNo ?? ''],
    ]);
  }

  private assertDevMode(): void {
    if (!this.devModeEnabled) {
      throw new ServiceUnavailableException(
        'MoMo merchant credentials are not configured.',
      );
    }
  }

  private async post(
    url: string,
    body: Record<string, string | number>,
  ): Promise<Record<string, unknown>> {
    let response: Response;
    try {
      response = await fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body),
        signal: AbortSignal.timeout(REQUEST_TIMEOUT_MS),
      });
    } catch {
      throw new BadGatewayException('Could not reach MoMo.');
    }
    if (!response.ok) {
      throw new BadGatewayException(`MoMo responded with ${response.status}.`);
    }
    try {
      return (await response.json()) as Record<string, unknown>;
    } catch {
      throw new BadGatewayException('MoMo returned an unreadable response.');
    }
  }
}
