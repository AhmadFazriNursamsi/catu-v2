import { isMove, leaveBlockMessage, takeRegionFields, usesTransferFlow } from './region-transfer-rules';

describe('region-transfer-rules', () => {
  it('Umat dan Pengurus Lingkungan memakai alur persetujuan, Koordinator dan Romo tidak', () => {
    expect(usesTransferFlow('UMAT')).toBe(true);
    expect(usesTransferFlow('UMAT_PENDATANG')).toBe(true);
    expect(usesTransferFlow('PENGURUS_LINGKUNGAN', 'KETUA')).toBe(true);
    expect(usesTransferFlow('PENGURUS_LINGKUNGAN', 'Koordinator Keuskupan')).toBe(false);
    expect(usesTransferFlow('ROMO_PAROKI')).toBe(false);
  });

  it('mengambil isian wilayah (camel dan snake) lalu menghapusnya dari DTO', () => {
    const dto: Record<string, any> = { fullName: 'A', keuskupanId: 1, paroki_id: '2', wilayahId: 3, lingkungan_id: 4 };
    expect(takeRegionFields(dto)).toEqual({ keuskupanId: 1, parokiId: 2, wilayahId: 3, lingkunganId: 4 });
    expect(dto).toEqual({ fullName: 'A' });
  });

  it('mengembalikan null bila tidak ada isian wilayah, dan nilai kosong menjadi null', () => {
    expect(takeRegionFields({ fullName: 'A' })).toBeNull();
    expect(takeRegionFields({ lingkunganId: '' })?.lingkunganId).toBeNull();
  });

  it('isMove membandingkan keempat tingkat', () => {
    const cur = { keuskupanId: 1, parokiId: 2, wilayahId: 3, lingkunganId: 4 };
    expect(isMove(cur, { ...cur })).toBe(false);
    expect(isMove(cur, { ...cur, lingkunganId: 5 })).toBe(true);
    expect(isMove(cur, { ...cur, lingkunganId: null })).toBe(true);
  });

  it('leaveBlockMessage menolak bila ada transaksi terbuka atau akun menunggu', () => {
    expect(leaveBlockMessage(0, 0)).toBeNull();
    expect(leaveBlockMessage(2, 0)).toContain('2 transaksi yang belum selesai');
    expect(leaveBlockMessage(0, 3)).toContain('3 akun yang menunggu persetujuan');
    expect(leaveBlockMessage(1, 1)).toContain('1 transaksi yang belum selesai dan 1 akun yang menunggu persetujuan');
  });
});
