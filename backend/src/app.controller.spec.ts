import { Test, TestingModule } from '@nestjs/testing';
import {
  AuthController,
  OrdersController,
  AssignmentsController,
  ChatController,
} from './app.controller';
import { AuthService } from './modules/auth/auth.service';
import { OrdersService } from './modules/orders/orders.service';
import { AssignmentsService } from './modules/assignments/assignments.service';
import { ChatService } from './modules/chat/chat.service';
import { DataSource } from 'typeorm';
import { JwtService } from '@nestjs/jwt';
import { FcmService } from './fcm.service';
import * as bcrypt from 'bcrypt';

describe('CATU v2 Controllers & Services (Unit Tests)', () => {
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
    query: jest.fn().mockResolvedValue([]),
  };

  const mockDataSource = {
    query: jest.fn().mockResolvedValue([]),
    createQueryRunner: jest.fn().mockReturnValue(mockQueryRunner),
  };

  const mockJwtService = {
    sign: jest.fn().mockReturnValue('mocked.jwt.token'),
    signAsync: jest.fn().mockResolvedValue('mocked.jwt.token'),
    verify: jest.fn().mockReturnValue({ sub: 1, roleCode: 'UMAT' }),
    verifyAsync: jest.fn().mockResolvedValue({ sub: 1, roleCode: 'UMAT' }),
  };

  const mockFcmService = {
    sendPushToUsers: jest.fn().mockResolvedValue({ successCount: 1, failureCount: 0 }),
    registerDeviceToken: jest.fn().mockResolvedValue({ success: true }),
    unregisterDeviceToken: jest.fn().mockResolvedValue({ success: true }),
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
        AuthService,
        OrdersService,
        AssignmentsService,
        ChatService,
        {
          provide: DataSource,
          useValue: mockDataSource,
        },
        {
          provide: JwtService,
          useValue: mockJwtService,
        },
        {
          provide: FcmService,
          useValue: mockFcmService,
        },
      ],
    }).compile();

    authController = module.get<AuthController>(AuthController);
    ordersController = module.get<OrdersController>(OrdersController);
    assignmentsController = module.get<AssignmentsController>(AssignmentsController);
    chatController = module.get<ChatController>(ChatController);

    jest.clearAllMocks();
    mockDataSource.query.mockResolvedValue([]);
    mockQueryRunner.query.mockResolvedValue([]);
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

      mockDataSource.query.mockResolvedValue([]);

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
      const hashed = await bcrypt.hash('password123', 10);
      mockDataSource.query.mockResolvedValueOnce([
        {
          id: 1,
          full_name: 'Umat Budi',
          phone_number: '6281234567890',
          password_hash: hashed,
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
      mockDataSource.query
        .mockResolvedValueOnce([]) // UPDATE auth_users
        .mockResolvedValueOnce([{ full_name: 'Umat Budi' }]) // SELECT full_name
        .mockResolvedValueOnce([]); // INSERT user_approvals

      const result = await authController.approveRegistration({
        targetUserId: 10,
        action: 'APPROVED',
      });

      expect(result.message).toContain('telah berhasil di-APPROVED');
    });
  });

  describe('OrdersController', () => {
    it('harus berhasil membuat Order Pelayanan & membentuk Group Chat WhatsApp otomatis', async () => {
      mockDataSource.query.mockImplementation(async (sql: string) => {
        if (sql.includes('auth_users') && sql.includes('LIMIT 1')) return [{ id: 1 }];
        if (sql.includes('user_profiles') && sql.includes('WHERE user_id')) return [{ keuskupan_id: 1, paroki_id: 10 }];
        if (sql.includes('INSERT INTO orders')) return [{ id: 101, order_number: 'ORD-20260811-0001', status: 'PENDING' }];
        if (sql.includes('INSERT INTO chat_groups')) return [{ id: 50 }];
        return [];
      });

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
      mockDataSource.query
        .mockResolvedValueOnce([{ id: 101, status: 'PENDING', accepted_romo_id: null }]) // existing orders
        .mockResolvedValueOnce([{ id: 101 }]) // update order
        .mockResolvedValueOnce([{ id: 50 }]) // chat group
        .mockResolvedValue([]); // other queries

      const result = await assignmentsController.respondAssignment('101', {
        status: 'ACCEPTED',
      });

      expect(result.status).toEqual('CONFIRMED');
      expect(result.message).toContain('CONFIRMED');
    });
  });

  describe('ChatController', () => {
    it('harus berhasil mengirim pesan chat ke WhatsApp Group', async () => {
      mockDataSource.query
        .mockResolvedValueOnce([{ id: 50 }]) // resolveGroupId: chat_groups check
        .mockResolvedValueOnce([
          {
            id: 5001,
            chat_group_id: 50,
            sender_id: 1,
            message_type: 'TEXT',
            message: 'Halo Romo',
          },
        ]) // insert chat_messages
        .mockResolvedValue([]); // subsequent queries

      const result = await chatController.sendMessage('50', {
        messageType: 'TEXT',
        message: 'Halo Romo',
      });

      expect(result.message).toContain('Pesan berhasil terkirim');
      expect(result.data.id).toEqual(5001);
    });
  });
});
