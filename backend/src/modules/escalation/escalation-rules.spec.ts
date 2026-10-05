import { isOpenForOrdo, opensAt, parseMinutes, validateSettings } from './escalation-rules';

describe('escalation-rules', () => {
  const created = new Date('2026-10-05T03:00:00Z');

  it('terbuka untuk Romo Ordo tepat setelah batas menit', () => {
    const order = { createdAt: created, hasParoki: true };
    expect(isOpenForOrdo(order, 10, new Date('2026-10-05T03:09:59Z'))).toBe(false);
    expect(isOpenForOrdo(order, 10, new Date('2026-10-05T03:10:00Z'))).toBe(true);
    expect(opensAt(created, 10).toISOString()).toBe('2026-10-05T03:10:00.000Z');
  });

  it('pelayanan tanpa paroki langsung terbuka', () => {
    expect(isOpenForOrdo({ createdAt: created, hasParoki: false }, 10, created)).toBe(true);
  });

  it('memvalidasi pengaturan', () => {
    expect(validateSettings({ ordoAfterMinutes: 10, koordinatorAfterMinutes: 20 })).toBeNull();
    expect(validateSettings({ ordoAfterMinutes: 10, koordinatorAfterMinutes: 10 })).toBeNull();
    expect(validateSettings({ ordoAfterMinutes: 30, koordinatorAfterMinutes: 20 })).toMatch(/Koordinator/);
    expect(validateSettings({ ordoAfterMinutes: -1, koordinatorAfterMinutes: 20 })).toMatch(/bilangan bulat/);
    expect(validateSettings({ ordoAfterMinutes: 1.5, koordinatorAfterMinutes: 20 })).toMatch(/bilangan bulat/);
  });

  it('parseMinutes memakai cadangan untuk nilai tidak sah', () => {
    expect(parseMinutes('15', 10)).toBe(15);
    expect(parseMinutes('abc', 10)).toBe(10);
    expect(parseMinutes('-3', 10)).toBe(10);
  });
});
