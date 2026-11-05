/** Tanggal hari ini menurut WIB, format YYYY-MM-DD. */
export function todayWib(now: Date = new Date()): string {
  return new Intl.DateTimeFormat('en-CA', { timeZone: 'Asia/Jakarta' }).format(now);
}

/** Pelayanan tidak boleh ditandai selesai sebelum tanggal pelaksanaannya (hari-H WIB boleh). Tanggal tak terbaca = tidak diblokir. */
export function doneTooEarlyError(scheduledDate: string | null | undefined, now: Date = new Date()): string | null {
  const d = (scheduledDate ?? '').slice(0, 10);
  if (!/^\d{4}-\d{2}-\d{2}$/.test(d) || d <= todayWib(now)) return null;
  return `Pelayanan baru dapat ditandai selesai pada atau setelah tanggal pelaksanaan (${d.split('-').reverse().join('/')}).`;
}
