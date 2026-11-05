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

  it('peran staf lain (Romo) tidak diperiksa lingkungan', async () => {
    await expect(make([]).assertOrderAccess({ sub: 6, roleCode: 'ROMO_PAROKI' }, 1)).resolves.toBeUndefined();
  });
});
