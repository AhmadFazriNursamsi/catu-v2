import { ForbiddenException, NotFoundException } from '@nestjs/common';
import { AccessService } from './access.service';

describe('AccessService.assertOrderAccess untuk Pengurus Lingkungan', () => {
  const pengurus = { sub: 9, roleCode: 'PENGURUS_LINGKUNGAN' };
  const make = (rows: any[]) => new AccessService({ query: jest.fn().mockResolvedValue(rows) } as any);

  it('lolos untuk pelayanan di lingkungannya', async () => {
    const svc = make([{ owner_id: 4, order_lingkungan_id: 100, pengurus_lingkungan_id: 100 }]);
    await expect(svc.assertOrderAccess(pengurus, 1)).resolves.toBeUndefined();
  });

  it('403 untuk pelayanan di lingkungan/paroki lain', async () => {
    const svc = make([{ owner_id: 4, order_lingkungan_id: 200, pengurus_lingkungan_id: 100 }]);
    await expect(svc.assertOrderAccess(pengurus, 1)).rejects.toBeInstanceOf(ForbiddenException);
  });

  it('404 bila pelayanan tidak ada', async () => {
    await expect(make([]).assertOrderAccess(pengurus, 1)).rejects.toBeInstanceOf(NotFoundException);
  });

  it('peran staf lain (Admin) tidak diperiksa wilayah', async () => {
    await expect(make([]).assertOrderAccess({ sub: 1, roleCode: 'ADMIN' }, 1)).resolves.toBeUndefined();
  });

  describe('Romo', () => {
    const romo = { sub: 6, roleCode: 'ROMO_PAROKI' };
    const row = { order_paroki_id: 187, order_kab_id: 3175, romo_paroki_id: 207, romo_kab_id: 3175, involved: false };

    it('403 untuk pelayanan paroki lain yang tidak ia tangani', async () => {
      await expect(make([row]).assertOrderAccess(romo, 1)).rejects.toBeInstanceOf(ForbiddenException);
    });

    it('lolos untuk pelayanan di parokinya', async () => {
      await expect(make([{ ...row, order_paroki_id: 207 }]).assertOrderAccess(romo, 1)).resolves.toBeUndefined();
    });

    it('lolos untuk pelayanan yang ia tangani/limpahan walau paroki lain', async () => {
      await expect(make([{ ...row, involved: true }]).assertOrderAccess(romo, 1)).resolves.toBeUndefined();
    });

    it('404 bila pelayanan tidak ada', async () => {
      await expect(make([]).assertOrderAccess(romo, 1)).rejects.toBeInstanceOf(NotFoundException);
    });
  });
});
