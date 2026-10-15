import { normalizeVietnamesePhone } from './phone.util';

describe('normalizeVietnamesePhone', () => {
  it('normalizes local Vietnamese numbers', () => {
    expect(normalizeVietnamesePhone('090 123 4567')).toBe('+84901234567');
  });

  it('preserves an international Vietnamese prefix', () => {
    expect(normalizeVietnamesePhone('+84 901 234 567')).toBe('+84901234567');
  });
});
