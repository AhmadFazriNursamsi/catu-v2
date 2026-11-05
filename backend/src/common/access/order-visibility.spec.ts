import { pengurusMayViewOrder } from './order-visibility';

describe('pengurusMayViewOrder', () => {
  const base = { pengurusId: 9, pengurusLingkunganId: 100, orderOwnerId: 4, orderLingkunganId: 100 };

  it('mengizinkan pelayanan dari lingkungannya sendiri', () => {
    expect(pengurusMayViewOrder(base)).toBe(true);
  });

  it('menolak pelayanan dari lingkungan lain (mis. paroki lain)', () => {
    expect(pengurusMayViewOrder({ ...base, orderLingkunganId: 200 })).toBe(false);
  });

  it('mengizinkan pelayanan yang ia ajukan sendiri walau lingkungannya berbeda', () => {
    expect(pengurusMayViewOrder({ ...base, orderOwnerId: 9, orderLingkunganId: 200 })).toBe(true);
  });

  it('menolak bila lingkungan pengurus atau pelayanan tidak diketahui', () => {
    expect(pengurusMayViewOrder({ ...base, pengurusLingkunganId: null })).toBe(false);
    expect(pengurusMayViewOrder({ ...base, orderLingkunganId: null })).toBe(false);
  });

  it('membandingkan id sebagai angka (string dari Postgres)', () => {
    expect(pengurusMayViewOrder({ ...base, orderLingkunganId: '100' as unknown as number })).toBe(true);
  });
});
