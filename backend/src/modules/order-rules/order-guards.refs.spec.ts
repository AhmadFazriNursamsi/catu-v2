import { BadRequestException } from '@nestjs/common';
import { OrderGuardsService } from './order-guards.service';

/** assertNewOrderRefs: referensi yang tidak ada harus 400 (bukan 500 dari pelanggaran FK). */
function build(missing: string[] = []) {
  const queries: string[] = [];
  const ds: any = {
    query: jest.fn(async (sql: string) => {
      queries.push(sql);
      return missing.some((t) => sql.includes(`FROM ${t} `)) ? [] : [{ '?column?': 1 }];
    }),
  };
  return { svc: new OrderGuardsService(ds), queries };
}
const ok = { serviceCategoryId: 1, urgencyLevelId: 1 };

describe('assertNewOrderRefs', () => {
  it.each([
    ['paroki', { parokiId: 9999999 }, /Paroki tidak ditemukan/],
    ['lingkungan', { lingkunganId: 99999999 }, /Lingkungan tidak ditemukan/],
    ['keuskupan', { keuskupanId: 9999 }, /Keuskupan tidak ditemukan/],
    ['wilayah', { wilayahId: 9999 }, /Wilayah tidak ditemukan/],
    ['kabupaten_kota', { kabupatenKotaId: 9999 }, /Kabupaten\/kota tidak ditemukan/],
  ])('menolak %s yang tidak ada dengan 400', async (table, extra, msg) => {
    const { svc } = build([table]);
    await expect(svc.assertNewOrderRefs({ ...ok, ...extra })).rejects.toThrow(BadRequestException);
    await expect(svc.assertNewOrderRefs({ ...ok, ...extra })).rejects.toThrow(msg);
  });

  it('kabupaten/kota pada item misa ikut diperiksa', async () => {
    const { svc } = build(['kabupaten_kota']);
    await expect(svc.assertNewOrderRefs({ ...ok, items: [{ kabupatenKotaId: 9999 }] })).rejects.toThrow(/Kabupaten\/kota/);
  });

  it('ID kosong, 0, atau null (mis. pendatang) tidak diperiksa', async () => {
    const { svc, queries } = build();
    await svc.assertNewOrderRefs({ ...ok, parokiId: 0, lingkunganId: null as any, wilayahId: undefined });
    expect(queries.filter((q) => /paroki|lingkungan|wilayah|keuskupan|kabupaten_kota/.test(q))).toHaveLength(0);
  });

  it('semua referensi sah lolos', async () => {
    const { svc } = build();
    await expect(svc.assertNewOrderRefs({ ...ok, keuskupanId: 1, parokiId: 187, wilayahId: 2, lingkunganId: 3157, kabupatenKotaId: 3175 })).resolves.toBeUndefined();
  });
});
