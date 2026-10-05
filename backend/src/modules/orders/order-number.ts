import { DataSource } from 'typeorm';

const WIB_OFFSET_MS = 7 * 60 * 60 * 1000;

/** Awalan nomor pelayanan per jenis: Sakramen Perminyakan "SM", Misa Kedukaan "MD". */
export function orderNumberPrefix(categoryName: string | null | undefined): string {
  const name = (categoryName ?? '').toLowerCase();
  if (name.includes('perminyakan')) return 'SM';
  if (name.includes('kedukaan')) return 'MD';
  return 'PL';
}

/** Hari bisnis (WIB) berformat YYYYMMDD. */
export function businessDay(date: Date): string {
  return new Date(date.getTime() + WIB_OFFSET_MS).toISOString().slice(0, 10).replace(/-/g, '');
}

/** Contoh: SM-20261005-0042 (awalan, hari WIB, urutan harian minimal 4 digit). */
export function formatOrderNumber(prefix: string, date: Date, sequence: number): string {
  return `${prefix}-${businessDay(date)}-${String(sequence).padStart(4, '0')}`;
}

/**
 * Nomor berurutan per jenis dan hari dari penghitung atomik di database, sehingga dua pelayanan yang dibuat
 * bersamaan tidak pernah mendapat nomor sama (sebelumnya 4 digit acak yang dapat bentrok dan menggagalkan pembuatan).
 */
export async function generateOrderNumber(dataSource: DataSource, categoryId: number): Promise<string> {
  const rows = await dataSource.query('SELECT name FROM service_categories WHERE id = $1', [categoryId]);
  const prefix = orderNumberPrefix(rows[0]?.name);
  const day = businessDay(new Date());
  const key = `${prefix}-${day}`;
  for (let attempt = 0; attempt < 10; attempt++) {
    const counter = await dataSource.query(
      `INSERT INTO order_number_counters (key, last_value) VALUES ($1, 1)
       ON CONFLICT (key) DO UPDATE SET last_value = order_number_counters.last_value + 1
       RETURNING last_value`,
      [key],
    );
    const number = formatOrderNumber(prefix, new Date(), Number(counter[0].last_value));
    // Nomor lama berformat acak pada hari yang sama dapat kebetulan sama: lewati bila sudah dipakai.
    const used = await dataSource.query('SELECT 1 FROM orders WHERE order_number = $1', [number]);
    if (used.length === 0) return number;
  }
  throw new Error('Gagal membuat nomor pelayanan unik');
}
