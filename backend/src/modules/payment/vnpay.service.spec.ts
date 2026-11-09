import { ServiceUnavailableException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { VnpayService } from './vnpay.service';

const fakeConfig = (values: Record<string, string>) =>
  ({ get: (key: string) => values[key] }) as unknown as ConfigService;

describe('VnpayService', () => {
  it('converts GMT+7 payment timestamps to UTC instants', () => {
    const service = new VnpayService(fakeConfig({}));

    expect(service.parsePaymentDate(20261108171500).toISOString()).toBe(
      '2026-11-08T10:15:00.000Z',
    );
    expect(service.parsePaymentDate('20261108000030').toISOString()).toBe(
      '2026-11-07T17:00:30.000Z',
    );
  });

  it('rejects payment timestamps that are not yyyyMMddHHmmss', () => {
    const service = new VnpayService(fakeConfig({}));

    expect(() => service.parsePaymentDate('2026-11-08 17:15:00')).toThrow(
      'invalid payment date',
    );
  });

  it('refuses to pay in production when merchant credentials are missing', () => {
    const service = new VnpayService(
      fakeConfig({ NODE_ENV: 'production', VNPAY_TMN_CODE: '' }),
    );
    const createdAt = new Date('2026-11-08T10:00:00.000Z');

    expect(() =>
      service.queryStatus({
        txnRef: '20261108ABCD',
        createdAt,
        amount: 1500000,
      }),
    ).toThrow(ServiceUnavailableException);
    expect(() =>
      service.buildCheckoutUrl({
        amount: 1500000,
        txnRef: '20261108ABCD',
        ip: '127.0.0.1',
        createdAt,
        orderInfo: 'Dat coc tro tot 20261108ABCD',
      }),
    ).toThrow(ServiceUnavailableException);
  });

  it('serves a dev checkout page and a pending status while credentials are absent', async () => {
    const service = new VnpayService(
      fakeConfig({
        NODE_ENV: 'development',
        PUBLIC_API_URL: 'http://10.0.2.2:3300',
      }),
    );

    const url = service.buildCheckoutUrl({
      amount: 1500000,
      txnRef: '20261108ABCD',
      ip: '127.0.0.1',
      createdAt: new Date('2026-11-08T10:00:00.000Z'),
      orderInfo: 'Dat coc tro tot 20261108ABCD',
    });
    expect(url).toBe(
      'http://10.0.2.2:3300/api/payment/dev/checkout/20261108ABCD',
    );

    const status = await service.queryStatus({
      txnRef: '20261108ABCD',
      createdAt: new Date('2026-11-08T10:00:00.000Z'),
      amount: 1500000,
    });
    expect(status.isVerified).toBe(true);
    expect(status.isSuccess).toBe(false);
    expect(status.vnp_TxnRef).toBe('20261108ABCD');
    expect(status.vnp_Amount).toBe(150000000);
  });

  it('round-trips VNPay payment stamps through GMT+7', () => {
    const service = new VnpayService(fakeConfig({}));

    const parsed = service.parsePaymentDate(20260927102708);
    expect(service.formatPaymentDate(parsed)).toBe('20260927102708');
  });
});
