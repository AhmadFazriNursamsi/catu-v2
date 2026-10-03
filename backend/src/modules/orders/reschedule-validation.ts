export const RESCHEDULE_REASON_MIN = 10;
export const RESCHEDULE_REASON_MAX = 300;
export const RESCHEDULE_MAX_DAYS_AHEAD = 60;

const WIB_OFFSET_MS = 7 * 60 * 60 * 1000;
const TIME_RE = /^([01]\d|2[0-3]):([0-5]\d)$/;
const DATE_RE = /^(\d{4})-(\d{2})-(\d{2})$/;

export interface RescheduleProposalInput {
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
 * Memvalidasi pengajuan perubahan jadwal. Mengembalikan pesan error pertama, atau null bila valid.
 * Waktu "sekarang" dihitung dalam WIB karena jadwal pelayanan memakai waktu setempat.
 */
export function validateRescheduleProposal(
  dto: RescheduleProposalInput,
  now: Date = new Date(),
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

  let isToday = false;
  const date = dto.newDate?.trim();
  if (date) {
    const m = DATE_RE.exec(date);
    const y = m ? Number(m[1]) : 0;
    const mo = m ? Number(m[2]) : 0;
    const d = m ? Number(m[3]) : 0;
    const ms = m ? Date.UTC(y, mo - 1, d) : NaN;
    const roundTrip = new Date(ms);
    if (
      !m ||
      Number.isNaN(ms) ||
      roundTrip.getUTCFullYear() !== y ||
      roundTrip.getUTCMonth() !== mo - 1 ||
      roundTrip.getUTCDate() !== d
    ) {
      return 'Tanggal baru tidak valid. Gunakan format TTTT-BB-HH.';
    }
    if (ms < todayMs) return 'Tanggal baru tidak boleh sudah lewat.';
    if ((ms - todayMs) / 86_400_000 > RESCHEDULE_MAX_DAYS_AHEAD) {
      return `Tanggal baru maksimal ${RESCHEDULE_MAX_DAYS_AHEAD} hari ke depan.`;
    }
    isToday = ms === todayMs;
  }
  if (isToday && toMinutes(start) <= nowMinutes) return 'Jam mulai baru sudah lewat untuk hari ini.';

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
