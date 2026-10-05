import { ApprovalAccount, approvalScope, decideApproval } from './approval-policy';
import { registrationError } from './registration-rules';

const acct = (over: Partial<ApprovalAccount>): ApprovalAccount => ({ id: 1, roleCode: 'UMAT', status: 'APPROVED', ...over });

const admin = acct({ id: 52, roleCode: 'ADMIN' });
const ketuaLing = acct({ id: 9, roleCode: 'PENGURUS_LINGKUNGAN', pengurusPosition: 'Ketua Lingkungan', lingkunganId: 100, keuskupanId: 30 });
const sekretaris = acct({ id: 11, roleCode: 'PENGURUS_LINGKUNGAN', pengurusPosition: 'Sekretaris', lingkunganId: 100, keuskupanId: 30 });
const koordinator = acct({ id: 53, roleCode: 'KOORDINATOR_KEUSKUPAN', pengurusPosition: 'Koordinator', keuskupanId: 30 });
const kepalaParoki = acct({ id: 12, roleCode: 'ROMO_PAROKI', romoPosition: 'Kepala Romo Paroki', parokiId: 256 });
const ketuaOrdo = acct({ id: 60, roleCode: 'ROMO_ORDO', romoPosition: 'Ketua Romo Ordo', ordoId: 2 });

const umat = acct({ id: 70, status: 'PENDING_APPROVAL', lingkunganId: 100, keuskupanId: 30 });
const pengurusBaru = acct({ id: 71, roleCode: 'PENGURUS_LINGKUNGAN', status: 'PENDING_APPROVAL', pengurusPosition: 'Bendahara', lingkunganId: 100, keuskupanId: 30, assignedApproverId: 9 });
const romoParoki = acct({ id: 72, roleCode: 'ROMO_PAROKI', status: 'PENDING_APPROVAL', romoPosition: 'ROMO_BIASA', parokiId: 256 });
const romoOrdo = acct({ id: 73, roleCode: 'ROMO_ORDO', status: 'PENDING_APPROVAL', romoPosition: 'ROMO_BIASA', ordoId: 2 });
const kepalaBaru = acct({ id: 74, roleCode: 'ROMO_PAROKI', status: 'PENDING_APPROVAL', romoPosition: 'KETUA_ROMO', parokiId: 258 });
const koordinatorBaru = acct({ id: 75, roleCode: 'KOORDINATOR_KEUSKUPAN', status: 'PENDING_APPROVAL', pengurusPosition: 'Koordinator', keuskupanId: 30 });

const allowed = (actor: ApprovalAccount, target: ApprovalAccount, action: 'APPROVE' | 'REJECT' = 'APPROVE') => decideApproval(actor, target, action).allowed;

describe('decideApproval', () => {
  it('Admin dapat memproses semua jenis akun pending', () => {
    for (const t of [umat, pengurusBaru, romoParoki, romoOrdo, kepalaBaru, koordinatorBaru]) expect(allowed(admin, t)).toBe(true);
  });

  it('umat: pengurus se-lingkungan dan koordinator se-keuskupan; pengurus lingkungan lain tidak', () => {
    expect(allowed(sekretaris, umat)).toBe(true);
    expect(allowed(ketuaLing, umat, 'REJECT')).toBe(true);
    expect(allowed(koordinator, umat)).toBe(true);
    expect(allowed({ ...sekretaris, id: 20, lingkunganId: 200 }, umat)).toBe(false);
    expect(allowed({ ...koordinator, id: 54, keuskupanId: 3 }, umat)).toBe(false);
  });

  it('calon pengurus: hanya Ketua Lingkungan / penyetuju ditunjuk / koordinator, bukan pengurus biasa', () => {
    expect(allowed(ketuaLing, pengurusBaru)).toBe(true);
    expect(allowed(koordinator, pengurusBaru)).toBe(true);
    expect(allowed(sekretaris, pengurusBaru)).toBe(false);
    expect(allowed(sekretaris, { ...pengurusBaru, assignedApproverId: 11 })).toBe(true);
  });

  it('Romo biasa: hanya Kepala paroki / Ketua ordo yang sama', () => {
    expect(allowed(kepalaParoki, romoParoki)).toBe(true);
    expect(allowed({ ...kepalaParoki, parokiId: 257 }, romoParoki)).toBe(false);
    expect(allowed(acct({ id: 13, roleCode: 'ROMO_PAROKI', romoPosition: 'ROMO_BIASA', parokiId: 256 }), romoParoki)).toBe(false);
    expect(allowed(ketuaOrdo, romoOrdo)).toBe(true);
    expect(allowed({ ...ketuaOrdo, ordoId: 3 }, romoOrdo)).toBe(false);
    expect(allowed(kepalaParoki, romoOrdo)).toBe(false);
  });

  it('Kepala / Ketua Romo dan Koordinator hanya dapat diproses Admin', () => {
    expect(allowed(kepalaParoki, kepalaBaru)).toBe(false);
    expect(allowed({ ...kepalaParoki, parokiId: 258 }, kepalaBaru)).toBe(false);
    expect(allowed(koordinator, koordinatorBaru)).toBe(false);
    expect(allowed(ketuaLing, koordinatorBaru)).toBe(false);
  });

  it('lintas jenis ditolak: Romo atas umat, pengurus atas Romo', () => {
    expect(allowed(kepalaParoki, umat)).toBe(false);
    expect(allowed(ketuaLing, romoParoki)).toBe(false);
    expect(allowed(umat, romoParoki)).toBe(false);
  });

  it('tidak boleh memproses akun sendiri dan penyetuju harus berstatus APPROVED', () => {
    expect(allowed({ ...pengurusBaru }, pengurusBaru)).toBe(false);
    expect(allowed({ ...kepalaParoki, status: 'PENDING_APPROVAL' }, romoParoki)).toBe(false);
    expect(allowed({ ...ketuaLing, status: 'REJECTED' }, umat)).toBe(false);
  });

  it('jabatan penyetuju yang tidak aktif tidak berwenang', () => {
    expect(allowed({ ...kepalaParoki, isJabatanActive: false }, romoParoki)).toBe(false);
    expect(allowed({ ...ketuaLing, isJabatanActive: false }, umat)).toBe(false);
  });

  it('hanya akun PENDING yang dapat diproses; Admin boleh mengaktifkan kembali akun REJECTED', () => {
    const approved = { ...umat, status: 'APPROVED' };
    const rejected = { ...umat, status: 'REJECTED' };
    expect(decideApproval(admin, approved, 'APPROVE')).toMatchObject({ allowed: false, status: 409 });
    expect(decideApproval(admin, approved, 'REJECT')).toMatchObject({ allowed: false, status: 409 });
    expect(allowed(admin, rejected, 'APPROVE')).toBe(true);
    expect(allowed(admin, rejected, 'REJECT')).toBe(false);
    expect(decideApproval(ketuaLing, rejected, 'APPROVE')).toMatchObject({ allowed: false, status: 409 });
  });
});

describe('approvalScope', () => {
  it('menentukan ruang lingkup daftar persetujuan', () => {
    expect(approvalScope(admin)).toEqual({ kind: 'ADMIN' });
    expect(approvalScope(ketuaLing)).toEqual({ kind: 'LINGKUNGAN', lingkunganId: 100 });
    expect(approvalScope(koordinator)).toEqual({ kind: 'KEUSKUPAN', keuskupanId: 30 });
    expect(approvalScope(kepalaParoki)).toEqual({ kind: 'PAROKI', parokiId: 256 });
    expect(approvalScope(ketuaOrdo)).toEqual({ kind: 'ORDO', ordoId: 2 });
  });

  it('tanpa wewenang: Romo biasa, umat, akun belum aktif, pengurus tanpa lingkungan', () => {
    expect(approvalScope(acct({ roleCode: 'ROMO_PAROKI', romoPosition: 'ROMO_BIASA', parokiId: 256 }))).toBeNull();
    expect(approvalScope(acct({ roleCode: 'UMAT' }))).toBeNull();
    expect(approvalScope({ ...ketuaLing, status: 'PENDING_APPROVAL' })).toBeNull();
    expect(approvalScope({ ...ketuaLing, lingkunganId: null })).toBeNull();
  });
});

describe('registrationError', () => {
  it('menolak jenis akun yang tidak boleh didaftarkan (Admin, peran sembarang)', () => {
    for (const roleCode of ['ADMIN', 'SUPERADMIN', 'HACKER', '']) expect(registrationError({ roleCode })).toMatch(/tidak dapat didaftarkan/);
  });

  it('mewajibkan wilayah sesuai jenis akun', () => {
    expect(registrationError({ roleCode: 'UMAT' })).toMatch(/Lingkungan/);
    expect(registrationError({ roleCode: 'UMAT', lingkunganId: 5 })).toBeNull();
    expect(registrationError({ roleCode: 'PENGURUS_LINGKUNGAN' })).toMatch(/Lingkungan/);
    expect(registrationError({ roleCode: 'ROMO_PAROKI' })).toMatch(/Paroki/);
    expect(registrationError({ roleCode: 'ROMO_ORDO', ordoId: 2 })).toBeNull();
    expect(registrationError({ roleCode: 'ROMO_ORDO' })).toMatch(/Ordo/);
    expect(registrationError({ roleCode: 'KOORDINATOR_KEUSKUPAN' })).toMatch(/Keuskupan/);
    expect(registrationError({ roleCode: 'UMAT_PENDATANG' })).toBeNull();
  });
});
