export const ADMIN_ROLES = ['SUPERADMIN', 'ADMIN'];
export const ROMO_ROLES = ['ROMO_PAROKI', 'ROMO_ORDO'];
export const APPROVER_ROLES = [
  ...ADMIN_ROLES,
  'PENGURUS_LINGKUNGAN',
  'KOORDINATOR_KEUSKUPAN',
  ...ROMO_ROLES,
];

/** Peran yang melayani/mengelola umat dan boleh melihat data lintas pengguna sesuai scope-nya. */
export const STAFF_ROLES = [
  ...ADMIN_ROLES,
  ...ROMO_ROLES,
  'PENGURUS_LINGKUNGAN',
  'KOORDINATOR_KEUSKUPAN',
];
