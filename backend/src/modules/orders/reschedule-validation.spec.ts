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

  it('ubah jam tidak mengubah tanggal: tanggal berbeda dari tanggal pelayanan ditolak, yang sama atau kosong diterima', () => {
    const at = (patch: Record<string, unknown>, current = '2026-10-04') => validateRescheduleProposal({ ...valid, ...patch } as any, NOW, current);
    expect(at({ newDate: '2026-10-05' })).toMatch(/tidak dapat mengubah tanggal/);
    expect(at({ newDate: '2026-10-03' })).toMatch(/tidak dapat mengubah tanggal/);
    expect(at({ newDate: '2026-10-04' })).toBeNull();
    expect(at({ newDate: '2026-10-04T00:00:00.000Z' })).toBeNull();
    expect(at({ newDate: undefined })).toBeNull();
    expect(at({ newDate: '2026-10-05' }, '')).toBeNull(); // tanggal pelayanan tidak diketahui
  });

  it('hari ini: jam mulai harus setelah waktu sekarang (WIB), diukur dari tanggal pelayanan', () => {
    const today = (start: string) => validateRescheduleProposal({ ...valid, newDate: undefined, newTimeStart: start, newTimeEnd: undefined } as any, NOW, '2026-10-03');
    expect(today('09:59')).toMatch(/sudah lewat/);
    expect(today('10:00')).toMatch(/sudah lewat/);
    expect(today('10:01')).toBeNull();
    // pelayanan besok: jam pagi pun boleh
    expect(validateRescheduleProposal({ ...valid, newDate: undefined, newTimeStart: '06:00', newTimeEnd: undefined } as any, NOW, '2026-10-04')).toBeNull();
  });

  it('memakai tanggal WIB, bukan UTC, untuk menentukan "hari ini"', () => {
    // 2026-10-03 20:00 UTC = 2026-10-04 03:00 WIB: pelayanan 2026-10-04 adalah hari ini, jam 02:00 sudah lewat.
    const lateUtc = new Date('2026-10-03T20:00:00Z');
    expect(validateRescheduleProposal({ ...valid, newDate: undefined, newTimeStart: '02:00', newTimeEnd: undefined } as any, lateUtc, '2026-10-04')).toMatch(/sudah lewat/);
    expect(validateRescheduleProposal({ ...valid, newDate: undefined, newTimeStart: '02:00', newTimeEnd: undefined } as any, lateUtc, '2026-10-03')).toBeNull(); // 3 Okt bukan hari ini di WIB
  });

  it('menolak alasan kosong, terlalu singkat, dan terlalu panjang', () => {
    expect(check({ reason: '' })).toMatch(/wajib/);
    expect(check({ reason: '   ' })).toMatch(/wajib/);
    expect(check({ reason: 'sakit' })).toMatch(/singkat/);
    expect(check({ reason: 'x'.repeat(301) })).toMatch(/maksimal/);
    expect(check({ reason: 'x'.repeat(300) })).toBeNull();
  });
});
