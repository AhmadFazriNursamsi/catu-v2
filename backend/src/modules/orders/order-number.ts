import { DataSource } from 'typeorm';

/** Awalan nomor pelayanan per jenis: Sakramen Perminyakan "SM", Misa Kedukaan "MD". */
export function orderNumberPrefix(categoryName: string | null | undefined): string {
  const name = (categoryName ?? '').toLowerCase();
  if (name.includes('perminyakan')) return 'SM';
  if (name.includes('kedukaan')) return 'MD';
  return 'PL';
}

/** Contoh: SM-20261005-4821 (awalan, tanggal, 4 digit acak). */
export function formatOrderNumber(prefix: string, date: Date, random: number): string {
  const ymd = date.toISOString().slice(0, 10).replace(/-/g, '');
  return `${prefix}-${ymd}-${random}`;
}

export async function generateOrderNumber(dataSource: DataSource, categoryId: number): Promise<string> {
  const rows = await dataSource.query('SELECT name FROM service_categories WHERE id = $1', [categoryId]);
  return formatOrderNumber(orderNumberPrefix(rows[0]?.name), new Date(), Math.floor(1000 + Math.random() * 9000));
}
