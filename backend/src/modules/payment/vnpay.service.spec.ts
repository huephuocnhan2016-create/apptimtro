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

  it('reports missing merchant credentials on the first call, not at startup', () => {
    const service = new VnpayService(fakeConfig({ VNPAY_TMN_CODE: '' }));

    expect(() =>
      service.queryStatus({
        txnRef: '20261108ABCD',
        createdAt: new Date('2026-11-08T10:00:00.000Z'),
      }),
    ).toThrow(ServiceUnavailableException);
  });
});
