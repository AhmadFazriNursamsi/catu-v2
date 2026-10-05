import { businessDay, formatOrderNumber, orderNumberPrefix } from './order-number';

describe('order-number', () => {
  it('memilih awalan sesuai jenis pelayanan', () => {
    expect(orderNumberPrefix('Sakramen Perminyakan')).toBe('SM');
    expect(orderNumberPrefix('Misa Kedukaan')).toBe('MD');
    expect(orderNumberPrefix(undefined)).toBe('PL');
  });

  it('memformat awalan-hari-urutan dengan minimal 4 digit', () => {
    expect(formatOrderNumber('SM', new Date('2026-10-05T03:00:00Z'), 4821)).toBe('SM-20261005-4821');
    expect(formatOrderNumber('MD', new Date('2026-01-09T03:00:00Z'), 7)).toBe('MD-20260109-0007');
    expect(formatOrderNumber('SM', new Date('2026-10-05T03:00:00Z'), 12345)).toBe('SM-20261005-12345');
  });

  it('hari mengikuti WIB (bukan UTC)', () => {
    expect(businessDay(new Date('2026-10-05T16:59:00Z'))).toBe('20261005'); // 23:59 WIB
    expect(businessDay(new Date('2026-10-05T17:01:00Z'))).toBe('20261006'); // 00:01 WIB berikutnya
  });
});
