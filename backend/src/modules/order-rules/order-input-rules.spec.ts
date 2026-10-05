import { validateNewOrder, validateReview } from './order-input-rules';

const NOW = new Date('2026-10-05T03:00:00Z'); // 10:00 WIB, 5 Okt 2026
const base = { scheduledDate: '2026-10-10', scheduledTime: '18:00', locationName: 'RS', addressDetail: 'Kamar 3', notes: 'ok' };

describe('validateNewOrder', () => {
  it('pelayanan sah', () => {
    expect(validateNewOrder(base, NOW)).toBeNull();
    expect(validateNewOrder({ ...base, scheduledDate: '2026-10-05', scheduledTime: '18:00:00' }, NOW)).toBeNull(); // hari ini
    expect(validateNewOrder({ ...base, scheduledDate: '2026-10-10T00:00:00.000Z' }, NOW)).toBeNull();
  });

  it('tanggal lampau (waktu WIB) ditolak, kemarin pun', () => {
    expect(validateNewOrder({ ...base, scheduledDate: '2020-01-01' }, NOW)).toMatch(/sudah lewat/);
    expect(validateNewOrder({ ...base, scheduledDate: '2026-10-04' }, NOW)).toMatch(/sudah lewat/);
    // 23:30 WIB 5 Okt = 16:30 UTC; hari ini tetap 5 Okt
    expect(validateNewOrder({ ...base, scheduledDate: '2026-10-05' }, new Date('2026-10-05T16:30:00Z'))).toBeNull();
    // 00:30 WIB 6 Okt = 17:30 UTC 5 Okt; 5 Okt sudah lewat
    expect(validateNewOrder({ ...base, scheduledDate: '2026-10-05' }, new Date('2026-10-05T17:30:00Z'))).toMatch(/sudah lewat/);
  });

  it('tanggal mustahil atau bukan tanggal ditolak', () => {
    expect(validateNewOrder({ ...base, scheduledDate: '2026-02-31' }, NOW)).toMatch(/tidak valid/);
    expect(validateNewOrder({ ...base, scheduledDate: 'bukan-tanggal' }, NOW)).toMatch(/tidak valid/);
    expect(validateNewOrder({ ...base, scheduledDate: undefined }, NOW)).toMatch(/tidak valid/);
  });

  it('jam harus berformat JJ:MM dan wajib', () => {
    for (const t of ['25:99', '7:00', 'sore', '18.00']) expect(validateNewOrder({ ...base, scheduledTime: t }, NOW)).toMatch(/Jam/);
    expect(validateNewOrder({ ...base, scheduledTime: '' }, NOW)).toMatch(/wajib/);
  });

  it('batas panjang catatan, lokasi, alamat', () => {
    expect(validateNewOrder({ ...base, notes: 'x'.repeat(2001) }, NOW)).toMatch(/Catatan maksimal/);
    expect(validateNewOrder({ ...base, notes: 'x'.repeat(2000) }, NOW)).toBeNull();
    expect(validateNewOrder({ ...base, locationName: 'x'.repeat(201) }, NOW)).toMatch(/Lokasi maksimal/);
    expect(validateNewOrder({ ...base, addressDetail: 'x'.repeat(501) }, NOW)).toMatch(/Alamat maksimal/);
  });

  it('setiap misa pada pelayanan multi-item divalidasi', () => {
    const items = [{ scheduledDate: '2026-10-11', scheduledTimeStart: '09:00', scheduledTimeEnd: '10:00' }, { scheduledDate: '2026-09-01', scheduledTimeStart: '09:00' }];
    expect(validateNewOrder({ ...base, items }, NOW)).toMatch(/misa ke-2.*sudah lewat/);
    expect(validateNewOrder({ ...base, items: [{ scheduledDate: '2026-10-11', scheduledTimeStart: '99:00' }] }, NOW)).toMatch(/Jam mulai misa ke-1/);
  });
});

describe('validateReview', () => {
  it('rating 1-5 bulat; kosong atau di luar rentang ditolak', () => {
    expect(validateReview({ rating: 5, reviewNotes: 'Baik' })).toBeNull();
    expect(validateReview({ reviewNotes: 'Tanpa bintang' })).toBeNull();
    for (const r of [0, 6, 9, -1, 2.5, 'abc']) expect(validateReview({ rating: r, reviewNotes: 'x' })).toMatch(/1 sampai 5/);
  });

  it('teks wajib dan dibatasi', () => {
    expect(validateReview({ rating: 5, reviewNotes: '   ' })).toMatch(/kosong/);
    expect(validateReview({ rating: 5, reviewNotes: 'x'.repeat(1001) })).toMatch(/maksimal/);
  });
});
