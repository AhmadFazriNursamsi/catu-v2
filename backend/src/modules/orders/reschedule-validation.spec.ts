import { validateRescheduleProposal } from './reschedule-validation';

// 2026-10-03 10:00 WIB = 03:00 UTC
const NOW = new Date('2026-10-03T03:00:00Z');
const valid = {
  newDate: '2026-10-04',
  newTimeStart: '18:00',
  newTimeEnd: '19:30',
  reason: 'Ada misa konselebrasi mendadak',
};
const check = (patch: Record<string, unknown>) =>
  validateRescheduleProposal({ ...valid, ...patch } as any, NOW);

describe('validateRescheduleProposal', () => {
  it('menerima pengajuan yang lengkap dan masuk akal', () => {
    expect(check({})).toBeNull();
    expect(check({ newTimeEnd: undefined })).toBeNull();
    expect(check({ newDate: undefined })).toBeNull();
  });

  it('menolak jam mulai kosong atau berformat salah', () => {
    expect(check({ newTimeStart: undefined })).toMatch(/Jam mulai/);
    expect(check({ newTimeStart: '25:00' })).toMatch(/Jam mulai/);
    expect(check({ newTimeStart: '6pm' })).toMatch(/Jam mulai/);
  });

  it('menolak jam selesai yang tidak setelah jam mulai atau salah format', () => {
    expect(check({ newTimeEnd: '18:00' })).toMatch(/setelah jam mulai/);
    expect(check({ newTimeEnd: '17:00' })).toMatch(/setelah jam mulai/);
    expect(check({ newTimeEnd: 'abc' })).toMatch(/Jam selesai/);
  });

  it('menolak tanggal tidak valid, lampau, dan terlalu jauh', () => {
    expect(check({ newDate: '2026-02-30' })).toMatch(/tidak valid/);
    expect(check({ newDate: '04/10/2026' })).toMatch(/tidak valid/);
    expect(check({ newDate: '2026-10-02' })).toMatch(/sudah lewat/);
    expect(check({ newDate: '2026-12-31' })).toMatch(/maksimal/);
    expect(check({ newDate: '2026-12-02' })).toBeNull(); // tepat 60 hari
  });

  it('hari ini: jam mulai harus setelah waktu sekarang (WIB)', () => {
    expect(check({ newDate: '2026-10-03', newTimeStart: '09:59', newTimeEnd: undefined })).toMatch(/sudah lewat/);
    expect(check({ newDate: '2026-10-03', newTimeStart: '10:00', newTimeEnd: undefined })).toMatch(/sudah lewat/);
    expect(check({ newDate: '2026-10-03', newTimeStart: '10:01', newTimeEnd: undefined })).toBeNull();
  });

  it('memakai tanggal WIB, bukan UTC, untuk menentukan "hari ini"', () => {
    // 2026-10-03 20:00 UTC = 2026-10-04 03:00 WIB, sehingga 2026-10-03 sudah lampau.
    const lateUtc = new Date('2026-10-03T20:00:00Z');
    expect(validateRescheduleProposal({ ...valid, newDate: '2026-10-03' }, lateUtc)).toMatch(/sudah lewat/);
  });

  it('menolak alasan kosong, terlalu singkat, dan terlalu panjang', () => {
    expect(check({ reason: '' })).toMatch(/wajib/);
    expect(check({ reason: '   ' })).toMatch(/wajib/);
    expect(check({ reason: 'sakit' })).toMatch(/singkat/);
    expect(check({ reason: 'x'.repeat(301) })).toMatch(/maksimal/);
    expect(check({ reason: 'x'.repeat(300) })).toBeNull();
  });
});
