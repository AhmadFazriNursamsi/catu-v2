import { BadRequestException, ConflictException, ForbiddenException } from '@nestjs/common';
import { RomoCancelService } from './romo-cancel.service';

describe('RomoCancelService (Batalkan Pelayanan oleh Romo limpahan)', () => {
  const setup = (target: { status: string; acceptedRomoId: number | null }, recipient: boolean) => {
    const queries: string[] = [];
    const run = async (sql: string) => {
      queries.push(sql);
      return sql.includes('FROM orders WHERE id') ? [{ user_id: 5, order_number: 'SM-1' }] : [{ full_name: 'Romo B' }];
    };
    const dataSource: any = { query: jest.fn(run), transaction: jest.fn(async (fn: any) => fn({ query: jest.fn(run) })) };
    const guards: any = { target: jest.fn().mockResolvedValue(target), isHandoverRecipient: jest.fn().mockResolvedValue(recipient) };
    const events: any = { itemName: jest.fn().mockResolvedValue('Misa Pelepasan'), postChat: jest.fn(), notify: jest.fn() };
    const orders: any = { getPengurusForOrder: jest.fn().mockResolvedValue([{ id: 9 }]) };
    return { svc: new RomoCancelService(dataSource, guards, events, orders), queries, events };
  };

  it('membatalkan misa: status FAIL, tercatat di riwayat, umat & pengurus diberi tahu', async () => {
    const { svc, queries, events } = setup({ status: 'CONFIRMED', acceptedRomoId: 3 }, true);
    const res = await svc.cancel(1, 7, 3, '  Sakit mendadak  ');
    expect(res.statusCode).toBe(200);
    expect(queries.some((q) => q.includes("SET status = 'FAIL'") && q.includes('order_items'))).toBe(true);
    expect(queries.some((q) => q.includes("'CANCELLED_BY_ROMO'"))).toBe(true);
    expect(events.notify).toHaveBeenCalledWith([5, 9], expect.objectContaining({ type: 'ORDER_CANCELLED_BY_ROMO' }));
    expect(events.notify.mock.calls[0][1].body).toContain('Sakit mendadak');
  });

  it('alasan wajib diisi', async () => {
    const { svc } = setup({ status: 'CONFIRMED', acceptedRomoId: 3 }, true);
    await expect(svc.cancel(1, 7, 3, '   ')).rejects.toBeInstanceOf(BadRequestException);
  });

  it('hanya Romo limpahan yang bertugas, dan hanya selama pelayanan berjalan', async () => {
    await expect(setup({ status: 'CONFIRMED', acceptedRomoId: 3 }, false).svc.cancel(1, 7, 3, 'x')).rejects.toBeInstanceOf(ForbiddenException);
    await expect(setup({ status: 'CONFIRMED', acceptedRomoId: 4 }, true).svc.cancel(1, 7, 3, 'x')).rejects.toBeInstanceOf(ForbiddenException);
    await expect(setup({ status: 'DONE', acceptedRomoId: 3 }, true).svc.cancel(1, 7, 3, 'x')).rejects.toBeInstanceOf(ConflictException);
  });
});
