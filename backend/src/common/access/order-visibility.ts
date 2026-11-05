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
