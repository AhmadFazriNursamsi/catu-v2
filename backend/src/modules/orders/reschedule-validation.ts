export const RESCHEDULE_REASON_MIN = 10;
export const RESCHEDULE_REASON_MAX = 300;

const WIB_OFFSET_MS = 7 * 60 * 60 * 1000;
const TIME_RE = /^([01]\d|2[0-3]):([0-5]\d)$/;
const DATE_RE = /^(\d{4})-(\d{2})-(\d{2})/;

export interface RescheduleProposalInput {
  /** Hanya diterima bila sama dengan tanggal pelayanan; ubah jam tidak mengubah tanggal. */
  newDate?: string;
  newTimeStart?: string;
  newTimeEnd?: string;
  reason?: string;
}

const toMinutes = (hhmm: string) => {
  const [h, m] = hhmm.split(':').map(Number);
  return h * 60 + m;
};

/**
 * Memvalidasi pengajuan ubah jam. Mengembalikan pesan error pertama, atau null bila valid.
 * Ubah jam tidak mengubah tanggal: [currentDate] (yyyy-MM-dd, tanggal pelayanan/misa) menentukan "hari ini",
 * dan [dto.newDate] yang berbeda dari tanggal itu ditolak. Waktu "sekarang" dihitung dalam WIB.
 */
export function validateRescheduleProposal(
  dto: RescheduleProposalInput,
  now: Date = new Date(),
  currentDate?: string,
): string | null {
  const wib = new Date(now.getTime() + WIB_OFFSET_MS);
  const todayMs = Date.UTC(wib.getUTCFullYear(), wib.getUTCMonth(), wib.getUTCDate());
  const nowMinutes = wib.getUTCHours() * 60 + wib.getUTCMinutes();

  const start = dto.newTimeStart?.trim();
  if (!start || !TIME_RE.test(start)) return 'Jam mulai baru tidak valid. Gunakan format JJ:MM, contoh 18:30.';

  const end = dto.newTimeEnd?.trim();
  if (end) {
    if (!TIME_RE.test(end)) return 'Jam selesai tidak valid. Gunakan format JJ:MM, contoh 19:30.';
    if (toMinutes(end) <= toMinutes(start)) return 'Jam selesai harus setelah jam mulai.';
  }

  const asked = dto.newDate?.trim().slice(0, 10);
  const current = DATE_RE.exec(currentDate ?? '');
  if (asked && current && asked !== current[0]) return 'Ubah jam tidak dapat mengubah tanggal pelayanan. Gunakan jam baru pada tanggal yang sama.';
  if (current && Date.UTC(Number(current[1]), Number(current[2]) - 1, Number(current[3])) === todayMs && toMinutes(start) <= nowMinutes) {
    return 'Jam mulai baru sudah lewat untuk hari ini.';
  }

  const reason = (dto.reason ?? '').trim();
  if (!reason) return 'Alasan perubahan jadwal wajib diisi.';
  if (reason.length < RESCHEDULE_REASON_MIN) {
    return `Alasan terlalu singkat, minimal ${RESCHEDULE_REASON_MIN} karakter.`;
  }
  if (reason.length > RESCHEDULE_REASON_MAX) {
    return `Alasan maksimal ${RESCHEDULE_REASON_MAX} karakter.`;
  }
  return null;
}
