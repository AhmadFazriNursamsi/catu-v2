import { Test, TestingModule } from '@nestjs/testing';
import { NotificationsService } from './notifications.service';
import { DataSource } from 'typeorm';
import { FcmService } from '../../fcm.service';

describe('NotificationsService (Unit Tests)', () => {
  let service: NotificationsService;

  const mockDataSource = {
    query: jest.fn().mockResolvedValue([]),
  };

  const mockFcmService = {
    registerDeviceToken: jest.fn().mockResolvedValue({ success: true }),
    unregisterDeviceToken: jest.fn().mockResolvedValue({ success: true }),
    sendPushToUsers: jest.fn().mockResolvedValue({ successCount: 1, failureCount: 0 }),
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        NotificationsService,
        {
          provide: DataSource,
          useValue: mockDataSource,
        },
        {
          provide: FcmService,
          useValue: mockFcmService,
        },
      ],
    }).compile();

    service = module.get<NotificationsService>(NotificationsService);
    jest.clearAllMocks();
  });

  it('harus mendaftarkan token perangkat FCM', async () => {
    const result = await service.registerDevice({
      userId: 1,
      fcmToken: 'test-fcm-token-12345',
      deviceType: 'ANDROID',
    });

    expect(result).toBeDefined();
    expect(mockFcmService.registerDeviceToken).toHaveBeenCalledWith(
      1,
      'test-fcm-token-12345',
      'ANDROID',
      undefined,
    );
  });

  it('harus menandai notifikasi sebagai sudah dibaca', async () => {
    mockDataSource.query.mockResolvedValueOnce([]);

    const result = await service.markRead(10);
    expect(result.success).toBe(true);
    expect(mockDataSource.query).toHaveBeenCalledWith(
      'UPDATE notifications SET is_read = true WHERE id = $1',
      [10],
    );
  });
});
