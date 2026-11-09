import { ServiceUnavailableException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createHmac } from 'node:crypto';
import { MomoService } from './momo.service';

const fakeConfig = (values: Record<string, string>) =>
  ({ get: (key: string) => values[key] }) as unknown as ConfigService;

const sign = (secret: string, raw: string) =>
  createHmac('sha256', secret).update(raw, 'utf8').digest('hex');

const credentials = {
  NODE_ENV: 'production',
  PUBLIC_API_URL: 'https://api.example.com',
  MOMO_PARTNER_CODE: 'MOMORETLT2026',
  MOMO_ACCESS_KEY: 'access-key',
  MOMO_SECRET_KEY: 'secret-key',
};

describe('MomoService', () => {
  afterEach(() => jest.restoreAllMocks());

  it('serves the shared dev checkout page while credentials are absent', async () => {
    const service = new MomoService(
      fakeConfig({
        NODE_ENV: 'development',
        PUBLIC_API_URL: 'http://10.0.2.2:3000',
      }),
    );

    await expect(
      service.createOrder({
        amount: 3000000,
        orderId: '20261109ABCD',
        orderInfo: 'Dat coc tro tot 20261109ABCD',
        requestId: 'request-1',
      }),
    ).resolves.toEqual({
      payUrl: 'http://10.0.2.2:3000/api/payment/dev/checkout/20261109ABCD',
      deeplink: null,
      qrCodeUrl: null,
    });
    await expect(
      service.queryOrder({ orderId: '20261109ABCD', requestId: 'request-1' }),
    ).resolves.toMatchObject({ isVerified: true, isSuccess: false });
  });

  it('refuses to pay in production when merchant credentials are missing', async () => {
    const service = new MomoService(fakeConfig({ NODE_ENV: 'production' }));

    await expect(
      service.createOrder({
        amount: 3000000,
        orderId: '20261109ABCD',
        orderInfo: 'Dat coc tro tot 20261109ABCD',
        requestId: 'request-1',
      }),
    ).rejects.toBeInstanceOf(ServiceUnavailableException);
    expect(() => service.parseResult({ orderId: '20261109ABCD' })).toThrow(
      ServiceUnavailableException,
    );
  });

  it('signs the create body over MoMo field order and keeps whole VND amounts', async () => {
    const service = new MomoService(fakeConfig(credentials));
    const fetchMock = jest.fn().mockResolvedValue({
      ok: true,
      json: async () => ({
        resultCode: 0,
        orderId: '20261109ABCD',
        message: 'Thanh toán thành công',
        payUrl: 'https://test-payment.momo.vn/v2/gateway/pay?id=abc',
        deeplink: 'momo://payment?token=abc',
        qrCodeUrl: 'https://momo.vn/qr/abc.png',
      }),
    });
    jest
      .spyOn(global, 'fetch')
      .mockImplementation(fetchMock as unknown as typeof fetch);

    const order = await service.createOrder({
      amount: 3000000,
      orderId: '20261109ABCD',
      orderInfo: 'Dat coc tro tot 20261109ABCD',
      requestId: 'request-1',
    });

    expect(order.payUrl).toContain('test-payment.momo.vn');
    // The demo opens the MoMo app first and only falls back to the web page,
    // so both links have to survive to the app.
    expect(order.deeplink).toBe('momo://payment?token=abc');
    expect(order.qrCodeUrl).toBe('https://momo.vn/qr/abc.png');
    const url = fetchMock.mock.calls[0][0] as string;
    expect(url).toBe('https://test-payment.momo.vn/v2/gateway/api/create');
    const body = JSON.parse(
      (fetchMock.mock.calls[0][1] as RequestInit).body as string,
    );
    // MoMo signs raw k=v pairs in its own order, so amount must not be scaled
    // the way VNPay scales it and an empty extraData still has to appear.
    expect(body.amount).toBe(3000000);
    expect(body.signature).toBe(
      sign(
        credentials.MOMO_SECRET_KEY,
        [
          'accessKey=access-key',
          'amount=3000000',
          'extraData=',
          'ipnUrl=https://api.example.com/api/payment/momo/ipn',
          'orderId=20261109ABCD',
          'orderInfo=Dat coc tro tot 20261109ABCD',
          'partnerCode=MOMORETLT2026',
          'redirectUrl=https://api.example.com/api/payment/momo/return',
          'requestId=request-1',
          'requestType=payWithApp',
        ].join('&'),
      ),
    );
  });

  it('reports a refused order instead of handing out a dead link', async () => {
    const service = new MomoService(fakeConfig(credentials));
    jest
      .spyOn(global, 'fetch')
      .mockResolvedValue({
        ok: true,
        json: async () => ({ resultCode: 1004, message: 'Đơn hàng đã tồn tại' }),
      } as unknown as Response);

    await expect(
      service.createOrder({
        amount: 3000000,
        orderId: '20261109ABCD',
        orderInfo: 'Dat coc tro tot 20261109ABCD',
        requestId: 'request-1',
      }),
    ).rejects.toThrow('Đơn hàng đã tồn tại');
  });

  it('accepts only a result whose signature matches', () => {
    const service = new MomoService(fakeConfig(credentials));
    const params: Record<string, string> = {
      accessKey: 'access-key',
      amount: '3000000',
      extraData: '',
      message: 'Thanh toán thành công',
      orderId: '20261109ABCD',
      orderInfo: 'Dat coc tro tot 20261109ABCD',
      orderType: 'payWithApp',
      partnerCode: 'MOMORETLT2026',
      payType: 'wallet',
      requestId: 'request-1',
      responseTime: '1762683300000',
      resultCode: '0',
      transId: '9042738472',
    };
    const rawFor = (overrides: Record<string, string> = {}) =>
      [
        ['accessKey', overrides.accessKey ?? params.accessKey],
        ['amount', overrides.amount ?? params.amount],
        ['extraData', overrides.extraData ?? params.extraData],
        ['message', overrides.message ?? params.message],
        ['orderId', overrides.orderId ?? params.orderId],
        ['orderInfo', overrides.orderInfo ?? params.orderInfo],
        ['orderType', overrides.orderType ?? params.orderType],
        ['partnerCode', overrides.partnerCode ?? params.partnerCode],
        ['payType', overrides.payType ?? params.payType],
        ['requestId', overrides.requestId ?? params.requestId],
        ['responseTime', overrides.responseTime ?? params.responseTime],
        ['resultCode', overrides.resultCode ?? params.resultCode],
        ['transId', overrides.transId ?? params.transId],
      ]
        .map(([key, value]) => `${key}=${value ?? ''}`)
        .join('&');

    const success = service.parseResult({
      ...params,
      signature: sign(credentials.MOMO_SECRET_KEY, rawFor()),
    });
    expect(success.isVerified).toBe(true);
    expect(success.isSuccess).toBe(true);
    expect(success.responseCode).toBe('00');
    expect(success.transactionNo).toBe('9042738472');
    expect(success.payDate?.toISOString()).toBe(
      new Date(1762683300000).toISOString(),
    );

    // Same signature, price edited in the query string.
    const forged = service.parseResult({
      ...params,
      amount: '1000',
      signature: sign(credentials.MOMO_SECRET_KEY, rawFor()),
    });
    expect(forged.isVerified).toBe(false);

    const cancelled = service.parseResult({
      ...params,
      resultCode: '1102',
      signature: sign(
        credentials.MOMO_SECRET_KEY,
        rawFor({ resultCode: '1102' }),
      ),
    });
    expect(cancelled.isVerified).toBe(true);
    expect(cancelled.isSuccess).toBe(false);
    // MoMo cancel codes land on the code the deposit table already reads.
    expect(cancelled.responseCode).toBe('24');
  });

  it('describes result codes the way the MoMo sample app does', () => {
    const service = new MomoService(fakeConfig(credentials));

    expect(service.describeResult('00')).toBe('Thành công.');
    expect(service.describeResult('24')).toBe('Giao dịch đã bị hủy.');
    expect(service.describeResult('7000')).toBe('Giao dịch đang được xử lý.');
    expect(service.describeResult('1001')).toBe(
      'Giao dịch thất bại do không đủ tiền.',
    );
    expect(service.describeResult('8888')).toBe('MoMo trả về mã 8888');
  });
});
