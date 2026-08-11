import { Test, TestingModule } from '@nestjs/testing';
import { AuthController, OrdersController, AssignmentsController, ChatController } from './app.controller';
import { DataSource } from 'typeorm';

describe('CATU v2 Controllers (Unit Tests)', () => {
  let authController: AuthController;
  let ordersController: OrdersController;
  let assignmentsController: AssignmentsController;
  let chatController: ChatController;

  const mockQueryRunner = {
    connect: jest.fn().mockResolvedValue(undefined),
    startTransaction: jest.fn().mockResolvedValue(undefined),
    commitTransaction: jest.fn().mockResolvedValue(undefined),
    rollbackTransaction: jest.fn().mockResolvedValue(undefined),
    release: jest.fn().mockResolvedValue(undefined),
    query: jest.fn(),
  };

  const mockDataSource = {
    query: jest.fn(),
    createQueryRunner: jest.fn().mockReturnValue(mockQueryRunner),
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      controllers: [
        AuthController,
        OrdersController,
        AssignmentsController,
        ChatController,
      ],
      providers: [
        {
          provide: DataSource,
          useValue: mockDataSource,
        },
      ],
    }).compile();

    authController = module.get<AuthController>(AuthController);
    ordersController = module.get<OrdersController>(OrdersController);
    assignmentsController = module.get<AssignmentsController>(AssignmentsController);
    chatController = module.get<ChatController>(ChatController);

    jest.clearAllMocks();
    mockDataSource.createQueryRunner.mockReturnValue(mockQueryRunner);
  });

  describe('AuthController', () => {
    it('harus memproses registrasi user dan mengembalikan status PENDING_APPROVAL (auth_users + user_profiles)', async () => {
      mockQueryRunner.query
        .mockResolvedValueOnce([{ id: 1 }]) // 1. SELECT id FROM roles
        .mockResolvedValueOnce([]) // 2. SELECT pengurus
        .mockResolvedValueOnce([
          {
            id: 10,
            uuid: 'uuid-1234',
            phone_number: '6281234567890',
            account_status: 'PENDING_APPROVAL',
          },
        ]) // 3. INSERT INTO auth_users
        .mockResolvedValueOnce([]); // 4. INSERT INTO user_profiles

      const dto = {
        fullName: 'Umat Budi',
        phoneNumber: '6281234567890',
        password: 'password123',
        roleCode: 'UMAT' as any,
        lingkunganId: 1001,
      };

      const result = await authController.register(dto);

      expect(result).toBeDefined();
      expect(result.message).toContain('Registrasi berhasil');
      expect(result.user.accountStatus).toEqual('PENDING_APPROVAL');
    });

    it('harus berhasil memproses login dengan nomor HP valid', async () => {
      mockDataSource.query.mockResolvedValueOnce([
        {
          id: 1,
          full_name: 'Umat Budi',
          phone_number: '6281234567890',
          password_hash: 'password123',
          account_status: 'APPROVED',
          role_code: 'UMAT',
        },
      ]);

      const result = await authController.login({
        phoneNumber: '6281234567890',
        password: 'password123',
      });

      expect(result.accessToken).toBeDefined();
      expect(result.user?.fullName).toEqual('Umat Budi');
    });

    it('harus memperbarui status akun pada fitur Approval Registrasi', async () => {
      mockDataSource.query.mockResolvedValueOnce([{ id: 10, account_status: 'APPROVED' }]);
      mockDataSource.query.mockResolvedValueOnce([{ full_name: 'Umat Budi' }]);
      mockDataSource.query.mockResolvedValueOnce([]);

      const result = await authController.approveRegistration({
        targetUserId: 10,
        action: 'APPROVED',
      });

      expect(result.message).toContain('telah berhasil di-APPROVED');
    });
  });

  describe('OrdersController', () => {
    it('harus berhasil membuat Order Pelayanan & membentuk Group Chat WhatsApp otomatis', async () => {
      mockDataSource.query.mockResolvedValueOnce([
        {
          id: 101,
          order_number: 'ORD-20260811-0001',
          status: 'PENDING',
        },
      ]);

      mockDataSource.query.mockResolvedValueOnce([{ id: 50 }]);
      mockDataSource.query.mockResolvedValue([]);
      mockDataSource.query.mockResolvedValueOnce([]);

      const dto = {
        serviceCategoryId: 2,
        urgencyLevelId: 3,
        scheduledDate: '2026-08-15',
        scheduledTime: '18:00',
        locationName: 'Rumah Duka Carolus Room 101',
        addressDetail: 'Jl. Salemba Raya No. 41',
      };

      const result = await ordersController.createOrder(dto);

      expect(result.order.id).toEqual(101);
      expect(result.chatGroupId).toEqual(50);
      expect(result.message).toContain('Group Chat WhatsApp telah otomatis dibentuk');
    });
  });

  describe('AssignmentsController', () => {
    it('harus memasukkan Romo ke Group Chat saat Romo menekan ACCEPT', async () => {
      mockDataSource.query.mockResolvedValueOnce([]);
      mockDataSource.query.mockResolvedValueOnce([{ id: 50 }]);
      mockDataSource.query.mockResolvedValueOnce([]);
      mockDataSource.query.mockResolvedValueOnce([]);

      const result = await assignmentsController.respondAssignment('101', {
        status: 'ACCEPTED',
      });

      expect(result.status).toEqual('ACCEPTED');
      expect(result.message).toContain('ACCEPTED tugas pelayanan');
    });
  });

  describe('ChatController', () => {
    it('harus berhasil mengirim pesan chat ke WhatsApp Group', async () => {
      mockDataSource.query.mockResolvedValueOnce([
        {
          id: 5001,
          chat_group_id: 50,
          sender_id: 1,
          message_type: 'TEXT',
          message: 'Halo Romo',
        },
      ]);
      mockDataSource.query.mockResolvedValueOnce([]);

      const result = await chatController.sendMessage('50', {
        messageType: 'TEXT',
        message: 'Halo Romo',
      });

      expect(result.message).toContain('Pesan berhasil terkirim');
      expect(result.data.id).toEqual(5001);
    });
  });
});
