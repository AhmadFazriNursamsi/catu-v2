import { AuthController } from './auth.controller';

/** Penjaga perubahan status akun lewat form profil / endpoint admin: tidak boleh jadi jalan pintas persetujuan. */
function build(current: { status: string } | null, isAdmin: boolean) {
  const authorize = jest.fn(async () => undefined);
  const ctrl: any = Object.create(AuthController.prototype);
  ctrl.access = { isAdmin: () => isAdmin };
  ctrl.approvalPolicy = { load: jest.fn(async () => current), authorize };
  return { guard: (dto: any) => ctrl.guardStatusChange({ sub: 5 }, 70, dto) as Promise<void>, authorize };
}

describe('guardStatusChange', () => {
  it('non-admin: field status dibuang diam-diam (pendaftar ditolak tidak bisa menyetujui diri sendiri)', async () => {
    const { guard, authorize } = build({ status: 'REJECTED' }, false);
    const dto: any = { fullName: 'A', accountStatus: 'APPROVED', account_status: 'APPROVED' };
    await guard(dto);
    expect(dto).toEqual({ fullName: 'A' });
    expect(authorize).not.toHaveBeenCalled();
  });

  it('admin menyetujui/menolak akun PENDING atau REJECTED: harus lolos kebijakan wewenang', async () => {
    for (const status of ['PENDING_APPROVAL', 'REJECTED']) {
      for (const [to, action] of [['APPROVED', 'APPROVE'], ['REJECTED', 'REJECT']] as const) {
        if (status === to) continue;
        const { guard, authorize } = build({ status }, true);
        await guard({ accountStatus: to });
        expect(authorize).toHaveBeenCalledWith(5, 70, action);
      }
    }
  });

  it('admin: kebijakan menolak (mis. target Umat) -> galat diteruskan, status tidak berubah', async () => {
    const { guard, authorize } = build({ status: 'PENDING_APPROVAL' }, true);
    authorize.mockRejectedValueOnce(new Error('403'));
    await expect(guard({ accountStatus: 'APPROVED' })).rejects.toThrow('403');
  });

  it('admin: tanpa perubahan status, menonaktifkan akun aktif, atau status lain tidak diperiksa', async () => {
    for (const [cur, dto] of [['PENDING_APPROVAL', {}], ['PENDING_APPROVAL', { accountStatus: 'PENDING_APPROVAL' }], ['APPROVED', { accountStatus: 'REJECTED' }], ['APPROVED', { accountStatus: 'APPROVED' }]] as const) {
      const { guard, authorize } = build({ status: cur }, true);
      await guard({ ...dto });
      expect(authorize).not.toHaveBeenCalled();
    }
  });
});
