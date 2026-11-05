/**
 * Pengurus Lingkungan hanya berwenang atas pelayanan di lingkungannya sendiri (atau yang ia ajukan sendiri).
 * Pembatasan ini ditegakkan di server; filter lingkungan dari klien tidak dipercaya.
 */
export const PENGURUS_ROLE = 'PENGURUS_LINGKUNGAN';

export interface PengurusOrderScope {
  pengurusId: number;
  pengurusLingkunganId: number | null;
  orderOwnerId: number;
  orderLingkunganId: number | null;
}

export function pengurusMayViewOrder(s: PengurusOrderScope): boolean {
  if (Number(s.orderOwnerId) === Number(s.pengurusId)) return true;
  if (s.pengurusLingkunganId == null || s.orderLingkunganId == null) return false;
  return Number(s.pengurusLingkunganId) === Number(s.orderLingkunganId);
}

/**
 * Romo hanya membaca pelayanan di wilayahnya (Romo Paroki: parokinya; Romo Ordo: kabupaten/kotanya) atau yang ia
 * tangani: penerima, pengaju/tujuan limpah tugas, atau pernah terlibat dalam riwayat limpahan.
 */
export const ROMO_PAROKI_ROLE = 'ROMO_PAROKI';
export const ROMO_ORDO_ROLE = 'ROMO_ORDO';

export interface RomoOrderScope {
  roleCode: string;
  romoParokiId: number | null;
  romoKabupatenKotaId: number | null;
  orderParokiId: number | null;
  orderKabupatenKotaId: number | null;
  /** Ia penerima, pengaju/tujuan limpah, atau tercatat di riwayat limpahan pelayanan/misa ini. */
  involved: boolean;
}

export function romoMayViewOrder(s: RomoOrderScope): boolean {
  if (s.involved) return true;
  if (s.roleCode === ROMO_PAROKI_ROLE) {
    return s.romoParokiId != null && s.orderParokiId != null && Number(s.romoParokiId) === Number(s.orderParokiId);
  }
  if (s.roleCode === ROMO_ORDO_ROLE) {
    return s.romoKabupatenKotaId != null && s.orderKabupatenKotaId != null
      && Number(s.romoKabupatenKotaId) === Number(s.orderKabupatenKotaId);
  }
  return false;
}
