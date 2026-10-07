/** Aturan masukan (murni) untuk pelayanan baru dan ulasan. Mengembalikan pesan galat pertama, atau null bila sah. */

const WIB_OFFSET_MS = 7 * 60 * 60 * 1000;
const TIME_RE = /^([01]\d|2[0-3]):[0-5]\d(:[0-5]\d)?$/;
const DATE_RE = /^(\d{4})-(\d{2})-(\d{2})/;

export const MAX_NOTES = 2000;
export const MAX_LOCATION = 200;
export const MAX_ADDRESS = 500;
export const MAX_REVIEW = 1000;
export const MAX_ITEM_NAME = 150;
export const MAX_ITEMS = 20;
const KEDUKAAN_CATEGORY_ID = 2;

interface ScheduleInput {
  scheduledDate?: string;
  scheduledTime?: string;
  scheduledTimeStart?: string;
  scheduledTimeEnd?: string;
}

export interface NewOrderInput extends ScheduleInput {
  serviceCategoryId?: number;
  locationName?: string;
  addressDetail?: string;
  notes?: string;
  items?: Array<ScheduleInput & { itemName?: string; locationName?: string }>;
}

const minutesOf = (t: string) => Number(t.slice(0, 2)) * 60 + Number(t.slice(3, 5));

/** Jam selesai harus sesudah jam mulai (keduanya sudah berformat sah). */
function endAfterStart(start: string | undefined, end: string | undefined, label: string): string | null {
  if (!start?.trim() || !end?.trim()) return null;
  return minutesOf(end.trim()) > minutesOf(start.trim()) ? null : `Jam selesai ${label} harus sesudah jam mulai.`;
}

const todayWib = (now: Date) => {
  const w = new Date(now.getTime() + WIB_OFFSET_MS);
  return Date.UTC(w.getUTCFullYear(), w.getUTCMonth(), w.getUTCDate());
};

/** Tanggal yang sah (bukan 31 Februari) dan tidak lampau (waktu WIB); jam berformat JJ:MM. */
function scheduleError(s: ScheduleInput, label: string, now: Date): string | null {
  const m = DATE_RE.exec(s.scheduledDate ?? '');
  if (!m) return `Tanggal ${label} tidak valid.`;
  const y = Number(m[1]);
  const mo = Number(m[2]);
  const d = Number(m[3]);
  const ms = Date.UTC(y, mo - 1, d);
  const round = new Date(ms);
  if (round.getUTCFullYear() !== y || round.getUTCMonth() !== mo - 1 || round.getUTCDate() !== d) return `Tanggal ${label} tidak valid.`;
  if (ms < todayWib(now)) return `Tanggal ${label} tidak boleh sudah lewat.`;
  for (const [field, value] of [['Jam', s.scheduledTime], ['Jam mulai', s.scheduledTimeStart], ['Jam selesai', s.scheduledTimeEnd]] as const) {
    if (value !== undefined && value !== null && value !== '' && !TIME_RE.test(value.trim())) return `${field} ${label} tidak valid. Gunakan format JJ:MM.`;
  }
  return null;
}

export function validateNewOrder(dto: NewOrderInput, now: Date = new Date()): string | null {
  const main = scheduleError(dto, 'pelayanan', now);
  if (main) return main;
  if (!dto.scheduledTime?.trim()) return 'Jam pelayanan wajib diisi.';
  if ((dto.notes ?? '').length > MAX_NOTES) return `Catatan maksimal ${MAX_NOTES} karakter.`;
  if ((dto.locationName ?? '').length > MAX_LOCATION) return `Lokasi maksimal ${MAX_LOCATION} karakter.`;
  if ((dto.addressDetail ?? '').length > MAX_ADDRESS) return `Alamat maksimal ${MAX_ADDRESS} karakter.`;
  const mainRange = endAfterStart(dto.scheduledTimeStart, dto.scheduledTimeEnd, 'pelayanan');
  if (mainRange) return mainRange;
  const items = dto.items ?? [];
  if (dto.serviceCategoryId === KEDUKAAN_CATEGORY_ID && items.length === 0) return 'Misa Kedukaan harus memuat minimal satu misa.';
  if (items.length > MAX_ITEMS) return `Jumlah misa maksimal ${MAX_ITEMS}.`;
  for (const [i, item] of items.entries()) {
    const label = `misa ke-${i + 1}`;
    const err = scheduleError(item, label, now) ?? itemError(item, label);
    if (err) return err;
  }
  return null;
}

/** Nama, lokasi, dan rentang jam sebuah misa: wajib diisi, tidak melebihi kolom basis data, selesai sesudah mulai. */
function itemError(item: ScheduleInput & { itemName?: string; locationName?: string }, label: string): string | null {
  const name = (item.itemName ?? '').trim();
  if (!name) return `Nama ${label} wajib diisi.`;
  if (name.length > MAX_ITEM_NAME) return `Nama ${label} maksimal ${MAX_ITEM_NAME} karakter.`;
  const place = (item.locationName ?? '').trim();
  if (!place) return `Lokasi ${label} wajib diisi.`;
  if (place.length > MAX_LOCATION) return `Lokasi ${label} maksimal ${MAX_LOCATION} karakter.`;
  if (!item.scheduledTimeStart?.trim() || !item.scheduledTimeEnd?.trim()) return `Jam mulai dan jam selesai ${label} wajib diisi.`;
  return endAfterStart(item.scheduledTimeStart, item.scheduledTimeEnd, label);
}

/** Ulasan: nilai bintang bila diisi harus bilangan bulat 1-5; teks wajib dan tidak melebihi batas. */
export function validateReview(input: { rating?: unknown; reviewNotes?: string }): string | null {
  if (input.rating !== undefined && input.rating !== null) {
    const r = Number(input.rating);
    if (!Number.isInteger(r) || r < 1 || r > 5) return 'Nilai bintang harus bilangan bulat 1 sampai 5.';
  }
  const text = (input.reviewNotes ?? '').trim();
  if (!text) return 'Ulasan tidak boleh kosong';
  if (text.length > MAX_REVIEW) return `Ulasan maksimal ${MAX_REVIEW} karakter.`;
  return null;
}
