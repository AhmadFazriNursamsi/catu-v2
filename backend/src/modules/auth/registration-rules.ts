/** Jenis akun yang boleh didaftarkan sendiri lewat API publik (peran Admin tidak pernah boleh). */
export const REGISTRABLE_ROLES = ['UMAT', 'UMAT_PENDATANG', 'PENGURUS_LINGKUNGAN', 'ROMO_PAROKI', 'ROMO_ORDO', 'KOORDINATOR', 'KOORDINATOR_KEUSKUPAN'];

interface RegistrationScope {
  roleCode: string;
  keuskupanId?: number;
  lingkunganId?: number;
  parokiId?: number;
  ordoId?: number;
}

/**
 * Pesan galat bila pendaftaran tidak sah, atau null. Jenis akun dibatasi dan wilayah wajib diisi sesuai jenis akun,
 * supaya setiap pendaftar memiliki penyetuju yang jelas (tidak ada akun tanpa wilayah yang menggantung).
 */
export function registrationError(dto: RegistrationScope): string | null {
  if (!REGISTRABLE_ROLES.includes(dto.roleCode)) return 'Jenis akun tidak dapat didaftarkan.';
  const missing = (label: string) => `${label} wajib dipilih.`;
  switch (dto.roleCode) {
    case 'UMAT':
    case 'PENGURUS_LINGKUNGAN':
      return dto.lingkunganId ? null : missing('Lingkungan');
    case 'ROMO_PAROKI':
      return dto.parokiId ? null : missing('Paroki');
    case 'ROMO_ORDO':
      return dto.ordoId ? null : missing('Ordo / tarekat');
    case 'KOORDINATOR':
    case 'KOORDINATOR_KEUSKUPAN':
      return dto.keuskupanId ? null : missing('Keuskupan');
    default:
      return null;
  }
}

/** Peran tujuan yang boleh dipilih Admin untuk tiap peran asal; peran yang tidak tercantum tidak dibatasi aturan ini. */
const ROLE_CHANGE_TARGETS: Record<string, string[]> = {
  UMAT: ['PENGURUS_LINGKUNGAN', 'KOORDINATOR'],
  PENGURUS_LINGKUNGAN: ['UMAT'],
  KOORDINATOR: ['UMAT'],
  UMAT_PENDATANG: [],
  ROMO_PAROKI: [],
  ROMO_ORDO: [],
};

const ROLE_CHANGE_MESSAGES: Record<string, string> = {
  UMAT: 'Umat hanya dapat diubah menjadi Pengurus Lingkungan atau Koordinator.',
  PENGURUS_LINGKUNGAN: 'Pengurus Lingkungan hanya dapat diubah menjadi Umat.',
  KOORDINATOR: 'Koordinator hanya dapat diubah menjadi Umat.',
  UMAT_PENDATANG: 'Peran Umat Pendatang tidak dapat diubah.',
  ROMO_PAROKI: 'Peran Romo tidak dapat diubah. Yang dapat diubah hanya posisi pastoral.',
  ROMO_ORDO: 'Peran Romo tidak dapat diubah. Yang dapat diubah hanya posisi pastoral.',
};

/** Peran efektif untuk aturan ganti peran: Koordinator disatukan, umat yang punya jabatan dianggap pengurus. */
export function effectiveRole(roleCode: string, pengurusPosition?: string | null): string {
  const role = (roleCode || '').toUpperCase();
  const pos = (pengurusPosition ?? '').trim().toLowerCase();
  if (role.startsWith('KOORDINATOR') || pos.includes('koordinator')) return 'KOORDINATOR';
  if (role === 'UMAT' && pos) return 'PENGURUS_LINGKUNGAN';
  return role;
}

/**
 * Pesan galat bila Admin mengganti peran dari [from] ke [to], atau null bila boleh.
 * Umat -> Pengurus Lingkungan / Koordinator; Pengurus Lingkungan & Koordinator -> Umat;
 * Umat Pendatang, Romo Paroki, dan Romo Ordo tidak dapat berganti peran (Romo hanya posisi pastoralnya).
 */
export function roleChangeError(from: string, to: string): string | null {
  const target = effectiveRole(to);
  const allowed = ROLE_CHANGE_TARGETS[from];
  if (!to || from === target || !allowed || allowed.includes(target)) return null;
  return ROLE_CHANGE_MESSAGES[from];
}
