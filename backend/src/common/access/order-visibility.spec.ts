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

import { romoMayViewOrder } from './order-visibility';

describe('romoMayViewOrder', () => {
  const paroki = { roleCode: 'ROMO_PAROKI', romoParokiId: 207, romoKabupatenKotaId: 3175, orderParokiId: 207, orderKabupatenKotaId: 3175, involved: false, lintasParoki: false };
  const ordo = { ...paroki, roleCode: 'ROMO_ORDO' };

  it('Romo Paroki membaca pelayanan di parokinya', () => {
    expect(romoMayViewOrder(paroki)).toBe(true);
  });

  it('Romo Paroki ditolak untuk paroki lain walau satu kota', () => {
    expect(romoMayViewOrder({ ...paroki, orderParokiId: 187 })).toBe(false);
  });

  it('Romo Paroki yang menangani/menerima limpahan boleh membaca di luar parokinya', () => {
    expect(romoMayViewOrder({ ...paroki, orderParokiId: 187, involved: true })).toBe(true);
  });

  it('Romo Paroki tanpa paroki atau pesanan tanpa paroki ditolak', () => {
    expect(romoMayViewOrder({ ...paroki, romoParokiId: null })).toBe(false);
    expect(romoMayViewOrder({ ...paroki, orderParokiId: null })).toBe(false);
  });

  it('Romo Paroki mana pun ditolak untuk pelayanan lintas paroki/Umat Pendatang, kecuali ia terlibat', () => {
    expect(romoMayViewOrder({ ...paroki, lintasParoki: true })).toBe(false);
    expect(romoMayViewOrder({ ...paroki, lintasParoki: true, involved: true })).toBe(true);
    expect(romoMayViewOrder({ ...ordo, lintasParoki: true })).toBe(true);
  });

  it('Romo Ordo dibatasi pada kabupaten/kotanya', () => {
    expect(romoMayViewOrder(ordo)).toBe(true);
    expect(romoMayViewOrder({ ...ordo, orderKabupatenKotaId: 3174 })).toBe(false);
    expect(romoMayViewOrder({ ...ordo, romoKabupatenKotaId: null })).toBe(false);
  });

  it('peran lain tidak lolos lewat aturan Romo', () => {
    expect(romoMayViewOrder({ ...paroki, roleCode: 'UMAT' })).toBe(false);
  });
});
