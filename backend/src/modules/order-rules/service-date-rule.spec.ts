import { doneTooEarlyError, todayWib } from './service-date-rule';

describe('doneTooEarlyError', () => {
  const now = new Date('2026-11-05T03:00:00Z'); // 10:00 WIB, 5 Nov 2026

  it('menolak DONE sebelum tanggal pelaksanaan', () => {
    expect(doneTooEarlyError('2026-11-25', now)).toMatch(/25\/11\/2026/);
    expect(doneTooEarlyError('2026-11-06', now)).not.toBeNull();
  });

  it('hari-H dan sesudahnya boleh', () => {
    expect(doneTooEarlyError('2026-11-05', now)).toBeNull();
    expect(doneTooEarlyError('2026-10-01', now)).toBeNull();
  });

  it('memakai tanggal WIB, bukan UTC', () => {
    const lateUtc = new Date('2026-11-05T20:00:00Z'); // 06 Nov 03:00 WIB
    expect(todayWib(lateUtc)).toBe('2026-11-06');
    expect(doneTooEarlyError('2026-11-06', lateUtc)).toBeNull();
  });

  it('tanggal kosong atau tak terbaca tidak memblokir', () => {
    for (const v of [null, undefined, '', 'bukan-tanggal']) expect(doneTooEarlyError(v as any, now)).toBeNull();
  });
});
