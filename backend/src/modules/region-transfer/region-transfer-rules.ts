/** Aturan murni perpindahan wilayah gereja (tanpa akses database). */

export interface RegionIds {
  keuskupanId: number | null;
  parokiId: number | null;
  wilayahId: number | null;
  lingkunganId: number | null;
}

const KEYS: Array<[keyof RegionIds, string, string]> = [
  ['keuskupanId', 'keuskupanId', 'keuskupan_id'],
  ['parokiId', 'parokiId', 'paroki_id'],
  ['wilayahId', 'wilayahId', 'wilayah_id'],
  ['lingkunganId', 'lingkunganId', 'lingkungan_id'],
];

const toId = (v: unknown): number | null => {
  const n = Number(v);
  return v != null && v !== '' && Number.isInteger(n) && n > 0 ? n : null;
};

/** Umat (termasuk pendatang) dan Pengurus Lingkungan memakai alur persetujuan pindah; peran lain mengubah wilayah lewat Admin. */
export const usesTransferFlow = (roleCode: string, pengurusPosition?: string | null) =>
  ['UMAT', 'UMAT_PENDATANG', 'PENGURUS_LINGKUNGAN'].includes(roleCode) && !/koordinator/i.test(pengurusPosition ?? '');

/**
 * Mengambil isian wilayah dari DTO (camelCase atau snake_case) dan MENGHAPUSNYA dari DTO.
 * Mengembalikan null bila DTO tidak memuat satu pun isian wilayah.
 */
export function takeRegionFields(dto: Record<string, any>): RegionIds | null {
  let present = false;
  const out: RegionIds = { keuskupanId: null, parokiId: null, wilayahId: null, lingkunganId: null };
  for (const [prop, camel, snake] of KEYS) {
    if (dto[camel] !== undefined || dto[snake] !== undefined) {
      present = true;
      out[prop] = toId(dto[camel] ?? dto[snake]);
    }
    delete dto[camel];
    delete dto[snake];
  }
  return present ? out : null;
}

/** Apakah tujuan berbeda dari wilayah sekarang (lingkungan sebagai penentu). */
export const isMove = (current: RegionIds, target: RegionIds) =>
  KEYS.some(([prop]) => (target[prop] ?? null) !== (current[prop] ?? null));
