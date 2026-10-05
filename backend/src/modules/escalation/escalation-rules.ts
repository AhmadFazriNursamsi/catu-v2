export const SETTING_ORDO_AFTER = 'escalation.ordo_after_minutes';
export const SETTING_KOORDINATOR_AFTER = 'escalation.koordinator_after_minutes';
export const DEFAULT_ORDO_AFTER_MINUTES = 10;
export const DEFAULT_KOORDINATOR_AFTER_MINUTES = 20;
export const MAX_ESCALATION_MINUTES = 1440;

/** Menit sejak pelayanan dibuat sampai terbuka untuk Romo Ordo dan sampai Koordinator diberi tahu. */
export interface EscalationSettings {
  ordoAfterMinutes: number;
  koordinatorAfterMinutes: number;
}

export function parseMinutes(raw: unknown, fallback: number): number {
  const n = Number(raw);
  return Number.isInteger(n) && n >= 0 && n <= MAX_ESCALATION_MINUTES ? n : fallback;
}

/** Pesan galat validasi, atau null bila pengaturan sah. */
export function validateSettings(s: EscalationSettings): string | null {
  for (const [label, v] of [['Romo Ordo', s.ordoAfterMinutes], ['Koordinator', s.koordinatorAfterMinutes]] as const) {
    if (!Number.isInteger(v) || v < 0 || v > MAX_ESCALATION_MINUTES) {
      return `Menit untuk ${label} harus bilangan bulat 0 sampai ${MAX_ESCALATION_MINUTES}.`;
    }
  }
  if (s.koordinatorAfterMinutes < s.ordoAfterMinutes) {
    return 'Menit untuk Koordinator tidak boleh lebih kecil dari menit untuk Romo Ordo.';
  }
  return null;
}

export function opensAt(createdAt: Date, minutes: number): Date {
  return new Date(createdAt.getTime() + minutes * 60_000);
}

/**
 * Pelayanan terbuka untuk Romo Ordo bila sudah lewat batas menit. Pelayanan tanpa paroki
 * (umat pendatang) tidak punya Romo Paroki yang perlu ditunggu, jadi langsung terbuka.
 */
export function isOpenForOrdo(order: { createdAt: Date; hasParoki: boolean }, ordoAfterMinutes: number, now: Date): boolean {
  if (!order.hasParoki) return true;
  return now.getTime() >= opensAt(order.createdAt, ordoAfterMinutes).getTime();
}
