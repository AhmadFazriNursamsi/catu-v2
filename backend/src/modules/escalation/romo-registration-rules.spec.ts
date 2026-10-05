import { generatePassword, normalizePhone } from './romo-registration-rules';

describe('romo-registration-rules', () => {
  it('menormalkan nomor HP ke awalan 62', () => {
    expect(normalizePhone('0812-3456-7890')).toBe('6281234567890');
    expect(normalizePhone('+62 812 3456 7890')).toBe('6281234567890');
    expect(normalizePhone('81234567890')).toBe('6281234567890');
    expect(normalizePhone('6281234567890')).toBe('6281234567890');
  });

  it('menolak nomor yang tidak masuk akal', () => {
    expect(normalizePhone('')).toBeNull();
    expect(normalizePhone('12345')).toBeNull();
    expect(normalizePhone('abc')).toBeNull();
    expect(normalizePhone('0812345')).toBeNull();
  });

  it('membuat kata sandi acak tanpa karakter yang mirip', () => {
    const a = generatePassword();
    expect(a).toHaveLength(10);
    expect(a).toMatch(/^[A-HJ-NP-Za-km-z2-9]+$/);
    expect(generatePassword()).not.toBe(a);
    expect(generatePassword(14)).toHaveLength(14);
  });
});
