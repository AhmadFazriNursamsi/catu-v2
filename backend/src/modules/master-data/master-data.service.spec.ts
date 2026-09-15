import { Test, TestingModule } from '@nestjs/testing';
import { MasterDataService } from './master-data.service';
import { DataSource } from 'typeorm';

describe('MasterDataService (Unit Tests)', () => {
  let service: MasterDataService;

  const mockDataSource = {
    query: jest.fn().mockResolvedValue([]),
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        MasterDataService,
        {
          provide: DataSource,
          useValue: mockDataSource,
        },
      ],
    }).compile();

    service = module.get<MasterDataService>(MasterDataService);
    jest.clearAllMocks();
  });

  it('harus mengembalikan daftar keuskupan dari database', async () => {
    mockDataSource.query.mockResolvedValueOnce([
      { id: 1, name: 'Keuskupan Agung Jakarta', total_paroki: 65 },
    ]);

    const result = await service.getAllKeuskupan();
    expect(result).toHaveLength(1);
    expect(result[0].name).toEqual('Keuskupan Agung Jakarta');
  });

  it('harus menambahkan keuskupan baru dengan nama valid', async () => {
    mockDataSource.query.mockResolvedValueOnce([
      { id: 30, name: 'Keuskupan Baru Test', code: 'KBT' },
    ]);

    const result = await service.createKeuskupan({
      name: 'Keuskupan Baru Test',
      code: 'KBT',
    });

    expect(result.success).toBe(true);
    expect(result.data.name).toEqual('Keuskupan Baru Test');
  });

  it('harus melempar error jika nama keuskupan kosong', async () => {
    await expect(service.createKeuskupan({ name: '   ' })).rejects.toThrow(
      'Nama Keuskupan tidak boleh kosong',
    );
  });
});
