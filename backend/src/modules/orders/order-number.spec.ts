import { formatOrderNumber, orderNumberPrefix } from './order-number';

describe('order-number', () => {
  it('memilih awalan sesuai jenis pelayanan', () => {
    expect(orderNumberPrefix('Sakramen Perminyakan')).toBe('SM');
    expect(orderNumberPrefix('Misa Kedukaan')).toBe('MD');
    expect(orderNumberPrefix(undefined)).toBe('PL');
  });

  it('memformat awalan-tanggal-4digit', () => {
    expect(formatOrderNumber('SM', new Date('2026-10-05T03:00:00Z'), 4821)).toBe('SM-20261005-4821');
    expect(formatOrderNumber('MD', new Date('2026-01-09T03:00:00Z'), 1000)).toMatch(/^MD-\d{8}-\d{4}$/);
  });
});
