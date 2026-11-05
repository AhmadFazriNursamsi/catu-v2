import { BadRequestException, ForbiddenException, NotFoundException } from '@nestjs/common';
import { OrdersService } from './orders.service';

/** Penolakan limpah tugas harus berupa exception (HTTP 4xx), bukan objek {statusCode} yang dijawab 201. */
describe('OrdersService.handoverOrder penolakan', () => {
  const make = (rows: any[]) => {
    const ds: any = { query: jest.fn().mockResolvedValue(rows) };
    return new OrdersService(ds, {} as any, {} as any, {} as any);
  };
  const dto = { romoId: 6, targetRomoId: 8, reason: 'x' };

  it('melempar 400 bila Romo pengganti kosong', async () => {
    await expect(make([]).handoverOrder('1', { romoId: 6, reason: 'x' })).rejects.toBeInstanceOf(BadRequestException);
  });

  it('melempar 404 bila pelayanan tidak ada', async () => {
    await expect(make([]).handoverOrder('1', dto)).rejects.toBeInstanceOf(NotFoundException);
  });

  it('melempar 403 bila pengaju bukan Romo yang bertugas', async () => {
    const row = { id: 1, order_number: 'X', user_id: 4, status: 'CONFIRMED', accepted_romo_id: 99, paroki_id: 1 };
    await expect(make([row]).handoverOrder('1', dto)).rejects.toBeInstanceOf(ForbiddenException);
  });
});
