/**
 * Kebijakan persetujuan pendaftaran akun (murni, tanpa akses database):
 * siapa yang berwenang menyetujui / menolak akun siapa.
 *
 *  - Admin / Super Admin: semua akun.
 *  - Umat biasa            -> Pengurus Lingkungan di lingkungan yang sama, atau Koordinator se-keuskupan.
 *  - Pengurus Lingkungan   -> Ketua Lingkungan (atau penyetuju yang ditunjuk) di lingkungan yang sama, atau Koordinator se-keuskupan.
 *  - Koordinator           -> hanya Admin.
 *  - Romo Paroki biasa     -> Kepala Romo Paroki yang sama.
 *  - Romo Ordo biasa       -> Ketua Romo Ordo yang sama.
 *  - Kepala / Ketua Romo   -> hanya Admin.
 * Tidak seorang pun boleh memproses akunnya sendiri, dan hanya akun PENDING_APPROVAL yang dapat diproses
 * (Admin boleh mengaktifkan kembali akun REJECTED).
 */

export const ADMIN_CODES = ['ADMIN', 'SUPERADMIN'];

export interface ApprovalAccount {
  id: number;
  roleCode: string;
  status: string;
  pengurusPosition?: string | null;
  romoPosition?: string | null;
  isJabatanActive?: boolean | null;
  keuskupanId?: number | null;
  lingkunganId?: number | null;
  parokiId?: number | null;
  ordoId?: number | null;
  assignedApproverId?: number | null;
}

export type ApprovalAction = 'APPROVE' | 'REJECT';
export type ApprovalDecision = { allowed: true } | { allowed: false; status: 403 | 409; message: string };

const same = (a?: number | null, b?: number | null) => a != null && b != null && Number(a) === Number(b);
const lower = (v?: string | null) => (v ?? '').toLowerCase();

export const isAdminRole = (code: string) => ADMIN_CODES.includes(code);
export const isKoordinator = (a: ApprovalAccount) => a.roleCode.includes('KOORDINATOR') || lower(a.pengurusPosition).includes('koordinator');
export const isLeaderRomo = (a: ApprovalAccount) => /ketua|kepala|superior/.test(lower(a.romoPosition));
const isPengurus = (a: ApprovalAccount) => !isKoordinator(a) && (a.roleCode === 'PENGURUS_LINGKUNGAN' || lower(a.pengurusPosition).trim() !== '');
const isKetuaLingkungan = (a: ApprovalAccount) => /ketua/.test(lower(a.pengurusPosition)) && !/wakil/.test(lower(a.pengurusPosition));
const active = (a: ApprovalAccount) => a.status === 'APPROVED' && a.isJabatanActive !== false;

const deny = (message: string, status: 403 | 409 = 403): ApprovalDecision => ({ allowed: false, status, message });

export function decideApproval(actor: ApprovalAccount, target: ApprovalAccount, action: ApprovalAction): ApprovalDecision {
  if (actor.status !== 'APPROVED') return deny('Akun Anda belum aktif untuk memproses persetujuan.');
  if (Number(actor.id) === Number(target.id)) return deny('Anda tidak dapat memproses persetujuan akun Anda sendiri.');

  const admin = isAdminRole(actor.roleCode);
  const reopenable = admin && action === 'APPROVE' && target.status === 'REJECTED';
  if (target.status !== 'PENDING_APPROVAL' && !reopenable) {
    return deny(`Akun ini sudah berstatus ${target.status} dan tidak dapat diproses lagi.`, 409);
  }
  if (admin) return { allowed: true };

  const outOfScope = deny('Anda tidak berwenang memproses persetujuan akun ini.');
  if (isKoordinator(target)) return deny('Pendaftaran Koordinator hanya dapat diproses Admin.');

  if (target.roleCode === 'ROMO_PAROKI') {
    if (isLeaderRomo(target)) return deny('Pendaftaran Kepala Romo Paroki hanya dapat diproses Admin.');
    return actor.roleCode === 'ROMO_PAROKI' && isLeaderRomo(actor) && active(actor) && same(actor.parokiId, target.parokiId) ? { allowed: true } : outOfScope;
  }
  if (target.roleCode === 'ROMO_ORDO') {
    if (isLeaderRomo(target)) return deny('Pendaftaran Ketua Romo Ordo hanya dapat diproses Admin.');
    return actor.roleCode === 'ROMO_ORDO' && isLeaderRomo(actor) && active(actor) && same(actor.ordoId, target.ordoId) ? { allowed: true } : outOfScope;
  }

  if (target.roleCode === 'UMAT' || target.roleCode === 'PENGURUS_LINGKUNGAN') {
    if (isKoordinator(actor) && active(actor) && same(actor.keuskupanId, target.keuskupanId)) return { allowed: true };
    if (!isPengurus(actor) || !active(actor) || !same(actor.lingkunganId, target.lingkunganId)) return outOfScope;
    if (isPengurus(target)) return isKetuaLingkungan(actor) || same(target.assignedApproverId, actor.id) ? { allowed: true } : outOfScope;
    return { allowed: true };
  }
  return outOfScope;
}

/** Ruang lingkup daftar persetujuan milik akun penyetuju (null = tidak punya wewenang menyetujui). */
export type ApprovalScope =
  | { kind: 'ADMIN' }
  | { kind: 'LINGKUNGAN'; lingkunganId: number }
  | { kind: 'KEUSKUPAN'; keuskupanId: number }
  | { kind: 'PAROKI'; parokiId: number }
  | { kind: 'ORDO'; ordoId: number };

export function approvalScope(actor: ApprovalAccount): ApprovalScope | null {
  if (actor.status !== 'APPROVED') return null;
  if (isAdminRole(actor.roleCode)) return { kind: 'ADMIN' };
  if (actor.roleCode === 'ROMO_PAROKI') return isLeaderRomo(actor) && active(actor) && actor.parokiId ? { kind: 'PAROKI', parokiId: Number(actor.parokiId) } : null;
  if (actor.roleCode === 'ROMO_ORDO') return isLeaderRomo(actor) && active(actor) && actor.ordoId ? { kind: 'ORDO', ordoId: Number(actor.ordoId) } : null;
  if (isKoordinator(actor)) return active(actor) && actor.keuskupanId ? { kind: 'KEUSKUPAN', keuskupanId: Number(actor.keuskupanId) } : null;
  if (isPengurus(actor)) return active(actor) && actor.lingkunganId ? { kind: 'LINGKUNGAN', lingkunganId: Number(actor.lingkunganId) } : null;
  return null;
}
