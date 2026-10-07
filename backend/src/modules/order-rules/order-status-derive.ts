import { ServiceStatus } from './order-status-machine';

const FINAL: ServiceStatus[] = ['DONE', 'CLOSE', 'FAIL'];

/**
 * Status pelayanan induk yang diturunkan dari status seluruh misanya (murni; kembaran SQL: [orderStatusFromItemsSql]).
 *
 * - Semua misa sudah final: DONE bila ada misa yang terlaksana, kalau tidak CLOSE bila ada yang ditutup, kalau tidak FAIL.
 * - Masih ada misa belum final: IN_PROGRESS bila ada yang berlangsung, CONFIRMED bila ada yang diterima, selain itu PENDING.
 * Misa yang sudah final tidak pernah menyeret pelayanan menjadi FAIL/CLOSE selama masih ada misa lain yang belum selesai.
 * Tanpa misa: null (status induk dipertahankan).
 */
export function deriveOrderStatus(itemStatuses: string[]): ServiceStatus | null {
  if (itemStatuses.length === 0) return null;
  const s = itemStatuses.map((x) => (x ?? '').toUpperCase());
  if (s.every((x) => (FINAL as string[]).includes(x))) return s.includes('DONE') ? 'DONE' : s.includes('CLOSE') ? 'CLOSE' : 'FAIL';
  if (s.includes('IN_PROGRESS')) return 'IN_PROGRESS';
  if (s.includes('CONFIRMED')) return 'CONFIRMED';
  return 'PENDING';
}

/** Ungkapan SQL (skalar teks, NULL bila tanpa misa) yang setara [deriveOrderStatus] untuk order `orderIdExpr`. */
export const orderStatusFromItemsSql = (orderIdExpr: string) => `(
  SELECT CASE
    WHEN COUNT(*) = 0 THEN NULL
    WHEN bool_and(COALESCE(i.status::text, 'PENDING') IN ('DONE', 'CLOSE', 'FAIL')) THEN
      CASE WHEN bool_or(COALESCE(i.status::text, 'PENDING') = 'DONE') THEN 'DONE' WHEN bool_or(COALESCE(i.status::text, 'PENDING') = 'CLOSE') THEN 'CLOSE' ELSE 'FAIL' END
    WHEN bool_or(COALESCE(i.status::text, 'PENDING') = 'IN_PROGRESS') THEN 'IN_PROGRESS'
    WHEN bool_or(COALESCE(i.status::text, 'PENDING') = 'CONFIRMED') THEN 'CONFIRMED'
    ELSE 'PENDING'
  END
  FROM order_items i WHERE i.order_id = ${orderIdExpr})`;
