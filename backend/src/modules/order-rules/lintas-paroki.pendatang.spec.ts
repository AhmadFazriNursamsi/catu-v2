import { LintasParokiService } from './lintas-paroki.service';

/** Pelayanan Umat Pendatang: langsung ke Romo Ordo kota tujuan (realtime), tanpa Romo Paroki dan tanpa Koordinator asal. */
describe('LintasParokiService.afterCreate untuk Umat Pendatang', () => {
  const make = (order: Record<string, unknown>) => {
    const calls: string[] = [];
    const ds: any = {
      query: jest.fn(async (sql: string) => {
        calls.push(sql);
        if (sql.includes('FROM orders o LEFT JOIN user_profiles pem')) return [order];
        if (sql.includes("r.code = 'ROMO_ORDO'")) return [{ id: 50 }, { id: 51 }];
        return [];
      }),
    };
    const events: any = { notifyPerItem: jest.fn().mockResolvedValue(undefined) };
    return { svc: new LintasParokiService(ds, events), ds, events, calls };
  };
  const pendatang = { order_number: 'X-1', user_id: 9, paroki_id: null, kabupaten_kota_id: 3175, pemohon_paroki: 187, category_name: 'Perminyakan', is_pendatang: true };

  it('menandai terbuka untuk Romo Ordo sekarang dan memberi tahu Romo Ordo kota tujuan', async () => {
    const { svc, events, calls } = make(pendatang);
    expect(await svc.afterCreate(1)).toBe(true);
    expect(calls.some((s) => s.includes('lintas_paroki = TRUE, ordo_notified_at = NOW()'))).toBe(true);
    expect(events.notifyPerItem.mock.calls[0][0]).toEqual([50, 51]);
    expect(events.notifyPerItem.mock.calls[0][2]({ name: 'Misa' }).body).toMatch(/Umat Pendatang/);
  });

  it('tidak mengikutkan Koordinator (tidak ada notifikasi ke Koordinator asal)', async () => {
    const { svc, events } = make(pendatang);
    await svc.afterCreate(1);
    expect(events.notifyPerItem.mock.calls[1][0]).toEqual([]);
  });

  it('tidak memasukkan siapa pun ke grup chat: Romo Ordo baru masuk setelah menerima pelayanan', async () => {
    const { svc, calls } = make(pendatang);
    await svc.afterCreate(1);
    expect(calls.some((s) => s.includes('INSERT INTO chat_group_members'))).toBe(false);
  });

  it('umat biasa satu paroki tetap bukan lintas paroki', async () => {
    const { svc, calls } = make({ ...pendatang, is_pendatang: false, paroki_id: 187 });
    expect(await svc.afterCreate(1)).toBe(false);
    expect(calls.some((s) => s.includes('lintas_paroki = TRUE'))).toBe(false);
  });
});
