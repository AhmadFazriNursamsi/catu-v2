/**
 * Mesin status pelayanan (murni): perpindahan status yang sah.
 *
 *   PENDING -> CONFIRMED (diterima Romo) | FAIL (lewat tanggal tanpa Romo, oleh Admin/sistem)
 *   CONFIRMED -> IN_PROGRESS | DONE | CLOSE
 *   IN_PROGRESS -> DONE | CLOSE
 *   DONE / CLOSE / FAIL -> final (tidak dapat diubah lagi)
 * Mengulang status yang sama (mis. CONFIRMED -> CONFIRMED) tidak mengubah apa pun dan tidak memicu notifikasi ganda.
 */
export type ServiceStatus = 'PENDING' | 'CONFIRMED' | 'IN_PROGRESS' | 'DONE' | 'CLOSE' | 'FAIL';

export const SERVICE_STATUSES: ServiceStatus[] = ['PENDING', 'CONFIRMED', 'IN_PROGRESS', 'DONE', 'CLOSE', 'FAIL'];
/** Pelayanan sudah diterima Romo dan belum selesai: Romo masih dapat mengubah jam atau melimpahkan. */
export const ONGOING_STATUSES: ServiceStatus[] = ['CONFIRMED', 'IN_PROGRESS'];

const NEXT: Record<ServiceStatus, ServiceStatus[]> = {
  PENDING: ['CONFIRMED', 'FAIL'],
  CONFIRMED: ['IN_PROGRESS', 'DONE', 'CLOSE'],
  IN_PROGRESS: ['DONE', 'CLOSE'],
  DONE: [],
  CLOSE: [],
  FAIL: [],
};

export type StatusDecision = { kind: 'ALLOWED' } | { kind: 'NOOP' } | { kind: 'DENIED'; message: string };

export const isServiceStatus = (s: string): s is ServiceStatus => (SERVICE_STATUSES as string[]).includes(s);

/** [isAdmin] hanya membuka FAIL dari PENDING; selebihnya aturan sama untuk semua. */
export function decideTransition(from: string, to: string, isAdmin = false): StatusDecision {
  const f = (from ?? '').toUpperCase();
  const t = (to ?? '').toUpperCase();
  if (!isServiceStatus(f) || !isServiceStatus(t)) return { kind: 'DENIED', message: `Status ${f || '-'} / ${t || '-'} tidak dikenal.` };
  if (f === t) return { kind: 'NOOP' };
  if (t === 'FAIL' && !isAdmin) return { kind: 'DENIED', message: 'Status FAIL hanya dapat ditetapkan oleh Admin atau sistem.' };
  if (NEXT[f].includes(t)) return { kind: 'ALLOWED' };
  return { kind: 'DENIED', message: `Status pelayanan tidak dapat diubah dari ${f} ke ${t}.` };
}
