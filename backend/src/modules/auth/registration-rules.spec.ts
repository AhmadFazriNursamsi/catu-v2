import { effectiveRole, roleChangeError } from './registration-rules';

describe('roleChangeError (ganti peran oleh Admin)', () => {
  it('Umat hanya boleh menjadi Pengurus Lingkungan atau Koordinator', () => {
    expect(roleChangeError('UMAT', 'PENGURUS_LINGKUNGAN')).toBeNull();
    expect(roleChangeError('UMAT', 'KOORDINATOR')).toBeNull();
    expect(roleChangeError('UMAT', 'KOORDINATOR_KEUSKUPAN')).toBeNull();
    expect(roleChangeError('UMAT', 'UMAT')).toBeNull();
    expect(roleChangeError('UMAT', 'ROMO_PAROKI')).toMatch(/Umat hanya/);
    expect(roleChangeError('UMAT', 'ROMO_ORDO')).toMatch(/Umat hanya/);
    expect(roleChangeError('UMAT', 'UMAT_PENDATANG')).toMatch(/Umat hanya/);
  });

  it('Romo Paroki dan Romo Ordo tidak dapat berganti peran', () => {
    expect(roleChangeError('ROMO_PAROKI', 'ROMO_PAROKI')).toBeNull();
    expect(roleChangeError('ROMO_ORDO', 'ROMO_ORDO')).toBeNull();
    for (const to of ['UMAT', 'PENGURUS_LINGKUNGAN', 'KOORDINATOR', 'ROMO_ORDO']) {
      expect(roleChangeError('ROMO_PAROKI', to)).toMatch(/Romo tidak dapat diubah/);
    }
    expect(roleChangeError('ROMO_ORDO', 'ROMO_PAROKI')).toMatch(/Romo tidak dapat diubah/);
  });

  it('Pengurus Lingkungan dan Koordinator hanya boleh menjadi Umat', () => {
    expect(roleChangeError('PENGURUS_LINGKUNGAN', 'UMAT')).toBeNull();
    expect(roleChangeError('KOORDINATOR', 'UMAT')).toBeNull();
    expect(roleChangeError('KOORDINATOR', 'KOORDINATOR_KEUSKUPAN')).toBeNull();
    expect(roleChangeError('PENGURUS_LINGKUNGAN', 'KOORDINATOR')).toMatch(/Pengurus Lingkungan hanya/);
    expect(roleChangeError('PENGURUS_LINGKUNGAN', 'ROMO_PAROKI')).toMatch(/Pengurus Lingkungan hanya/);
    expect(roleChangeError('KOORDINATOR', 'PENGURUS_LINGKUNGAN')).toMatch(/Koordinator hanya/);
    expect(roleChangeError('KOORDINATOR', 'UMAT_PENDATANG')).toMatch(/Koordinator hanya/);
  });

  it('Umat Pendatang tidak dapat berganti peran; tanpa roleCode tidak ada yang diperiksa', () => {
    expect(roleChangeError('UMAT_PENDATANG', 'UMAT_PENDATANG')).toBeNull();
    for (const to of ['UMAT', 'PENGURUS_LINGKUNGAN', 'KOORDINATOR']) {
      expect(roleChangeError('UMAT_PENDATANG', to)).toMatch(/Umat Pendatang tidak dapat/);
    }
    expect(roleChangeError('ROMO_PAROKI', '')).toBeNull();
  });

  it('peran efektif menyatukan Koordinator dan umat berjabatan', () => {
    expect(effectiveRole('KOORDINATOR_KEUSKUPAN')).toBe('KOORDINATOR');
    expect(effectiveRole('PENGURUS_LINGKUNGAN', 'Koordinator')).toBe('KOORDINATOR');
    expect(effectiveRole('UMAT', 'Sekretaris')).toBe('PENGURUS_LINGKUNGAN');
    expect(effectiveRole('UMAT', null)).toBe('UMAT');
  });
});
