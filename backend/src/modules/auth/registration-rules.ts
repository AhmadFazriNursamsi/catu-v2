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
