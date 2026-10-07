import { isLintasParoki, orderKeuskupanSql } from './lintas-paroki';

describe('isLintasParoki', () => {
  it('paroki penerima sama dengan paroki pemohon: bukan lintas', () => {
    expect(isLintasParoki(256, 256)).toBe(false);
    expect(isLintasParoki('256', 256)).toBe(false);
  });

  it('paroki penerima berbeda dari paroki pemohon: lintas', () => {
    expect(isLintasParoki(257, 256)).toBe(true);
    expect(isLintasParoki(1, 256)).toBe(true);
    expect(isLintasParoki(257, null)).toBe(true);
  });

  it('tanpa paroki penerima (umat pendatang): bukan lintas, ditangani langsung Romo Ordo', () => {
    expect(isLintasParoki(null, 256)).toBe(false);
    expect(isLintasParoki(undefined, null)).toBe(false);
  });
});

describe('orderKeuskupanSql', () => {
  it('memakai ekspresi order yang diberikan dan hanya menambah keuskupan tujuan bila lintas', () => {
    const sql = orderKeuskupanSql('$1');
    expect(sql).toContain('ox.id = $1');
    expect(sql).toContain('ox.lintas_paroki');
    expect(orderKeuskupanSql('o.id')).toContain('ox.id = o.id');
  });
});
