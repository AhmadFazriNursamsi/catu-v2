import {
  Controller,
  Post,
  Put,
  Delete,
  Body,
  Get,
  Param,
  Query,
  OnModuleInit,
  BadRequestException,
  NotFoundException,
  HttpCode,
} from '@nestjs/common';
import {
  ApiTags,
  ApiOperation,
  ApiResponse,
  ApiBearerAuth,
} from '@nestjs/swagger';
import { InjectDataSource } from '@nestjs/typeorm';
import { DataSource } from 'typeorm';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcrypt';
import {
  RegisterUserDto,
  LoginDto,
  ApproveUserDto,
  RegisterResponseDto,
  LoginResponseDto,
  ApproveUserResponseDto,
  RoleCodeEnum,
  RequestResetOtpDto,
  VerifyResetOtpDto,
  ResetPasswordDto,
} from '../../auth.dto';
import {
  CreateOrderDto,
  RespondOrderAssignmentDto,
  SendChatMessageDto,
  UpdateUserProfileDto,
  CreateKeuskupanDto,
  UpdateKeuskupanDto,
  CreateParokiDto,
  UpdateParokiDto,
  CreateWilayahDto,
  UpdateWilayahDto,
  CreateLingkunganDto,
  UpdateLingkunganDto,
  CreateOrdoDto,
  UpdateOrdoDto,
  CreateServiceCategoryDto,
  UpdateServiceCategoryDto,
  CreateRoleDto,
  UpdateRoleDto,
  CreatePositionDto,
  UpdatePositionDto,
} from '../../orders.dto';
import { FcmService } from '../../fcm.service';

@ApiTags('Auth & Registration')
@Controller('auth')
export class AuthController implements OnModuleInit {
  constructor(
    @InjectDataSource() private dataSource: DataSource,
    private readonly jwtService: JwtService,
  ) {}

  async onModuleInit() {
    try {
      await this.dataSource.query(`
        ALTER TABLE user_profiles
        ADD COLUMN IF NOT EXISTS jabatan_start_year INT,
        ADD COLUMN IF NOT EXISTS jabatan_end_year INT,
        ADD COLUMN IF NOT EXISTS jabatan_start_date VARCHAR(20),
        ADD COLUMN IF NOT EXISTS jabatan_end_date VARCHAR(20),
        ADD COLUMN IF NOT EXISTS is_jabatan_active BOOLEAN DEFAULT FALSE,
        ADD COLUMN IF NOT EXISTS birth_date VARCHAR(20),
        ADD COLUMN IF NOT EXISTS address TEXT,
        ADD COLUMN IF NOT EXISTS avatar_url TEXT;

        ALTER TABLE user_profiles ALTER COLUMN pengurus_position TYPE VARCHAR(100) USING pengurus_position::text;
        ALTER TABLE user_profiles ALTER COLUMN romo_position TYPE VARCHAR(100) USING romo_position::text;

        ALTER TABLE orders ADD COLUMN IF NOT EXISTS attachment_url TEXT, ADD COLUMN IF NOT EXISTS accepted_romo_id INT;

        -- Auto-sync PostgreSQL sequences to prevent duplicate key errors on insert
        SELECT setval('keuskupan_id_seq', (SELECT COALESCE(MAX(id), 1) FROM keuskupan));
        SELECT setval('paroki_id_seq', (SELECT COALESCE(MAX(id), 1) FROM paroki));
        SELECT setval('wilayah_id_seq', (SELECT COALESCE(MAX(id), 1) FROM wilayah));
        SELECT setval('lingkungan_id_seq', (SELECT COALESCE(MAX(id), 1) FROM lingkungan));
        SELECT setval('ordo_id_seq', (SELECT COALESCE(MAX(id), 1) FROM ordo));
        SELECT setval('service_categories_id_seq', (SELECT COALESCE(MAX(id), 1) FROM service_categories));
        SELECT setval('urgency_levels_id_seq', (SELECT COALESCE(MAX(id), 1) FROM urgency_levels));
        SELECT setval('master_positions_id_seq', (SELECT COALESCE(MAX(id), 1) FROM master_positions));
        SELECT setval('auth_users_id_seq', (SELECT COALESCE(MAX(id), 1) FROM auth_users));
        SELECT setval('user_profiles_id_seq', (SELECT COALESCE(MAX(id), 1) FROM user_profiles));
        SELECT setval('orders_id_seq', (SELECT COALESCE(MAX(id), 1) FROM orders));
        SELECT setval('order_items_id_seq', (SELECT COALESCE(MAX(id), 1) FROM order_items));
        SELECT setval('order_reschedules_id_seq', (SELECT COALESCE(MAX(id), 1) FROM order_reschedules));
        SELECT setval('order_romo_handovers_id_seq', (SELECT COALESCE(MAX(id), 1) FROM order_romo_handovers));
        SELECT setval('chat_groups_id_seq', (SELECT COALESCE(MAX(id), 1) FROM chat_groups));
        SELECT setval('chat_group_members_id_seq', (SELECT COALESCE(MAX(id), 1) FROM chat_group_members));
        SELECT setval('chat_messages_id_seq', (SELECT COALESCE(MAX(id), 1) FROM chat_messages));
        SELECT setval('notifications_id_seq', (SELECT COALESCE(MAX(id), 1) FROM notifications));
      `);

      for (const val of ['CONFIRMED', 'DONE', 'CLOSE', 'FAIL']) {
        try {
          await this.dataSource.query(`ALTER TYPE order_status_enum ADD VALUE IF NOT EXISTS '${val}'`);
        } catch (_) {}
      }

      await this.dataSource.query(`
        UPDATE orders SET status = 'CONFIRMED' WHERE status::text = 'ACCEPTED';
        UPDATE orders SET status = 'DONE' WHERE status::text = 'SELESAI' OR status::text = 'COMPLETED';
        UPDATE orders SET status = 'FAIL' WHERE status::text = 'REJECTED';
        UPDATE orders SET status = 'FAIL' WHERE status::text = 'PENDING' AND (scheduled_date < CURRENT_DATE);

        -- Cleanup existing non-Romo profiles so romo_position is NULL
        UPDATE user_profiles
        SET romo_position = NULL
        WHERE user_id IN (
          SELECT u.id FROM auth_users u
          JOIN roles r ON u.role_id = r.id
          WHERE r.code NOT LIKE 'ROMO%'
        );

        -- Cleanup existing Romo Ordo profiles so keuskupan_id, paroki_id, etc. are NULL
        UPDATE user_profiles
        SET keuskupan_id = NULL, paroki_id = NULL, wilayah_id = NULL, lingkungan_id = NULL
        WHERE user_id IN (
          SELECT u.id FROM auth_users u
          JOIN roles r ON u.role_id = r.id
          WHERE r.code = 'ROMO_ORDO'
        );

        -- Cleanup active flag for non-leadership positions (ordinary Umat & ordinary Romo)
        UPDATE user_profiles
        SET is_jabatan_active = NULL
        WHERE pengurus_position IS NULL
          AND (romo_position IS NULL OR romo_position NOT IN ('Kepala Romo Paroki', 'Ketua Romo Ordo', 'KETUA_ROMO'));

        -- Create master tables if not exist
        CREATE TABLE IF NOT EXISTS keuskupan (id INT PRIMARY KEY, name VARCHAR(255) NOT NULL);
        CREATE TABLE IF NOT EXISTS paroki (id INT PRIMARY KEY, name VARCHAR(255) NOT NULL, keuskupan_id INT);
        CREATE TABLE IF NOT EXISTS wilayah (id INT PRIMARY KEY, paroki_id INT, name VARCHAR(255) NOT NULL);
        CREATE TABLE IF NOT EXISTS lingkungan (id INT PRIMARY KEY, wilayah_id INT, name VARCHAR(255) NOT NULL);
        CREATE TABLE IF NOT EXISTS ordo (id INT PRIMARY KEY, code VARCHAR(50) NOT NULL, name VARCHAR(255) NOT NULL);
        CREATE TABLE IF NOT EXISTS master_positions (
          id SERIAL PRIMARY KEY,
          category VARCHAR(50) NOT NULL,
          code VARCHAR(50) NOT NULL UNIQUE,
          name VARCHAR(100) NOT NULL,
          is_lead BOOLEAN DEFAULT FALSE,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );

        INSERT INTO master_positions (category, code, name, is_lead) VALUES
          ('PENGURUS_LINGKUNGAN', 'KOORDINATOR', 'Koordinator', TRUE),
          ('PENGURUS_LINGKUNGAN', 'KETUA_LINGKUNGAN', 'Ketua Lingkungan', TRUE),
          ('PENGURUS_LINGKUNGAN', 'WAKIL_KETUA', 'Wakil Ketua', FALSE),
          ('PENGURUS_LINGKUNGAN', 'SEKRETARIS', 'Sekretaris', FALSE),
          ('ROMO_PAROKI', 'KEPALA_ROMO_PAROKI', 'Kepala Romo Paroki', TRUE),
          ('ROMO_PAROKI', 'ROMO_PAROKI', 'Romo Paroki', FALSE),
          ('ROMO_ORDO', 'KETUA_ROMO_ORDO', 'Ketua Romo Ordo', TRUE),
          ('ROMO_ORDO', 'ROMO_ORDO', 'Romo Ordo', FALSE)
        ON CONFLICT (code) DO UPDATE SET
          category = EXCLUDED.category,
          name = EXCLUDED.name,
          is_lead = EXCLUDED.is_lead;

        -- Seed user keuskupan data
        INSERT INTO keuskupan (id, name) VALUES
          (1, 'Keuskupan Agung Jakarta'),
          (3, 'Keuskupan Agung Bandung'),
          (4, 'Keuskupan Agung Surabaya'),
          (9, 'Keuskupan Agung Solo'),
          (10, 'Keuskupan Agung Malang'),
          (11, 'Keuskupan Nusa Tenggara Timur'),
          (12, 'Nasional'),
          (17, 'Keuskupan Agung Singapore'),
          (18, 'Keuskupan Agung Kuala Lumpur'),
          (20, 'Kevikepan Surabaya Barat'),
          (21, 'Kevikepan Surabaya Utara'),
          (22, 'Kevikepan Surabaya Selatan'),
          (23, 'Kevikepan Mojokerto'),
          (24, 'Kevikepan Kediri'),
          (25, 'Kevikepan Blora'),
          (26, 'Kevikepan Madiun'),
          (27, 'Kevikepan Blitar')
        ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name;

        -- Seed user paroki data (id, name, keuskupan_id)
        INSERT INTO paroki (id, name, keuskupan_id) VALUES
          (1, 'Paroki Katedral - St. Perawan Maria Diangkat ke surga', 1),
          (2, 'Paroki Cempaka Putih – St. Paskalis', 1),
          (4, 'Paroki Kramat - Hati Kudus', 1),
          (6, 'Paroki Menteng - St. Theresia', 1),
          (7, 'Paroki Cilincing - Salib Suci', 1),
          (8, 'Paroki Danau Sunter - St. Yohanes Don Bosco', 1),
          (9, 'Paroki Kelapa Gading - St. Yakobus', 1),
          (10, 'Paroki Pademangan - St. Alfonsus Rodriguez', 1),
          (11, 'Paroki Pantai Indah Kapuk - Regina Caeli', 1),
          (12, 'Paroki Pluit - Stella Maris', 1),
          (13, 'Paroki Sunter – St. Lukas', 1),
          (95, 'Dekanat Bandung Timur', 3),
          (96, 'Dekanat Bandung Barat', 3),
          (98, 'Paroki Bekasi - St. Arnoldus Janssen', 1),
          (100, 'Paroki santa maria solo', 9),
          (102, 'Paroki NTT 1', 11),
          (103, 'Paroki NTT2', 11),
          (104, 'Paroki NTT 3', 11),
          (105, 'Paroki ntt 10', 11),
          (106, 'Paroki 1 Surabaya', 4),
          (107, 'Paroki 2 Surabaya', 4),
          (108, 'Paroki 3 Surabaya', 4),
          (109, 'Paroki Duri Kosambi', 1),
          (110, 'Nasional', 12),
          (114, 'Dekanat Bandung Selatan', 3),
          (117, 'Regio Barat', 10),
          (118, 'Regio Timur', 10),
          (119, 'Paroki Bekasi Utara - St. Clara', 1),
          (120, 'Paroki Cikarang - Ibu Teresa', 1),
          (122, 'Paroki Harapan Indah - St. Albertus Agung', 1),
          (124, 'Paroki Kampung Sawah - St. Servatius', 1),
          (125, 'Paroki Lubang Buaya - Kalvari', 1),
          (127, 'Paroki Kranggan - St. Stanislaus Kostka', 1),
          (129, 'Paroki Tanjung Priok - St. Fransiskus Xaverius', 1),
          (131, 'Dekanat Pantura', 3),
          (133, 'Dekanat Priangan', 3),
          (134, 'Paroki Duren Sawit - St. Anna', 1),
          (135, 'Paroki Matraman-St. Yoseph', 1),
          (136, 'Paroki Cililitan - St. Robertus Bellarminus', 1),
          (137, 'Paroki Cilangkap - St. Yohanes Maria Vianney', 1),
          (140, 'Paroki Serpong - St. Monika', 1),
          (144, 'Paroki Kemakmuran - Bunda Hati Kudus', 1),
          (146, 'Paroki Mangga Besar - St. Petrus dan Paulus', 1),
          (147, 'Paroki Tangerang - Hati Santa Perawan Maria Tak Bernoda', 1),
          (148, 'Paroki Teluk Naga (St. Maria Immaculata)', 1),
          (149, 'Paroki Jalan Malang - St. Ignatius Loyola', 1),
          (150, 'Paroki Blok B - St. Yohanes Penginjil', 1),
          (152, 'Paroki Blok Q - St. Perawan Maria Ratu', 1),
          (153, 'Paroki Grogol - St. Kristoforus', 1),
          (154, 'Paroki Tebet - St. Fransiskus Asisi', 1),
          (155, 'Paroki Pasar Minggu - Keluarga Kudus', 1),
          (156, 'Paroki Slipi - Kristus Salvator', 1),
          (157, 'Paroki Rawamangun - Keluarga Kudus', 1),
          (158, 'Paroki Perumnas Klender (St. Yoakhim)', 1),
          (159, 'Paroki Pondok Kelapa (Maria Bintang Samudra)', 1),
          (161, 'Paroki Cijantung - St. Aloysius Gonzaga', 1),
          (162, 'Paroki Cengkareng - Trinitas', 1),
          (163, 'Paroki Tomang - Maria Bunda Karmel', 1),
          (164, 'Paroki Cilandak - St. Stefanus', 1),
          (165, 'Paroki Pulomas - St. Bonaventura', 1),
          (166, 'Paroki Rawalumbu - St. Yohanes Paulus II', 1),
          (167, 'Paroki Cibitung - St. Petrus Rasul', 1),
          (168, 'Paroki Bojong Indah-St. Thomas Rasul', 1),
          (169, 'Paroki Bintaro - St. Matius Penginjil', 1),
          (170, 'Paroki Kedoya - St. Andreas', 1),
          (171, 'Paroki Karawaci - St. Agustinus', 1),
          (172, 'Paroki Pinang - St. Bernadet', 1),
          (173, 'Paroki Kranji - St. Mikael', 1),
          (174, 'Paroki Jati waringin - St. Leo Agung', 1),
          (175, 'Paroki Meruya - Maria Kusuma Karmel', 1),
          (176, 'Paroki Kapuk - St. Philipus Rasul', 1),
          (178, 'Paroki Jagakarsa - Ratu Rosari', 1),
          (179, 'Paroki Pulo Gebang - St. Gabriel', 1),
          (180, 'Paroki Taman Galaksi - St. Bartolomeus', 1),
          (181, 'Paroki Ciputat - St. Nikodemus', 1),
          (183, 'Paroki Kosambi Baru - St. Matias Rasul', 1),
          (184, 'Paroki Curug - St. Helena', 1),
          (185, 'Paroki Citra Raya - St. Odilia', 1),
          (186, 'Paroki Bintaro Jaya - St. Maria Regina', 1),
          (187, 'Paroki Alam Sutera - St. Laurensius', 1),
          (190, 'Paroki Kalideres - St. Maria Imakulata', 1),
          (191, 'Paroki Dadap (St. Vincentius Palloti )', 1),
          (192, 'Paroki Villa Melati Mas - St. Ambrosius', 1),
          (193, 'Paroki Halim - St. Agustinus', 1),
          (198, 'Paroki Puspa Gading', 1),
          (199, 'Paroki Singapore Utara', 17),
          (200, 'Paroki Singapore Selatan', 17),
          (201, 'Paroki KL Sentral', 18),
          (202, 'Paroki KL Utara', 18),
          (203, 'Paroki Singapore Barat', 17),
          (204, 'Paroki Singapore Timur', 17),
          (205, 'Paroki Singapore Timur Laut', 17),
          (206, 'Paroki Pejompongan - Kristus Raja', 1),
          (207, 'Aloysius Gonzaga', 20),
          (208, 'Redemptor Mundi', 20),
          (209, 'St. Yakobus', 20),
          (210, 'St. Yusup - Karpil', 20),
          (211, 'Sakramen Maha Kudus', 20),
          (212, 'St. Stefanus - Tandes', 20),
          (213, 'Kelahiran Santa Perawan Maria', 21),
          (214, 'St. Mikael-Perak', 21),
          (215, 'St.Vincentius A Paulo - Widodaren', 21),
          (216, 'St. Marinus Yohanes', 21),
          (217, 'Ratu Pecinta Damai', 21),
          (218, 'Kristus Raja - Ketabang', 21),
          (219, 'St. Maria Tak Bercela -Ngagel', 21),
          (220, 'St. Yosafat - Medokan Semampir', 21),
          (221, 'Katedral Hati Kudus Yesus', 22),
          (222, 'Yohanes Pemandi', 22),
          (223, 'Roh Kudus', 22),
          (224, 'Gembala Yang Baik', 22),
          (225, 'Salib Suci - Tropodo', 22),
          (226, 'St. Paulus - Juanda', 22),
          (227, 'St. Maria Annuntiata', 22),
          (228, 'St. Monika - Krian', 23),
          (229, 'St. Maria - Jombang', 23),
          (230, 'St. Yosef - Mojokerto', 23),
          (231, 'Santa Perawan Maria - Gresik', 23),
          (232, 'St. Vincentius A Paulo - Kediri', 24),
          (233, 'St. Yosef - Kediri', 24),
          (234, 'St. Mateus - Pare', 24),
          (235, 'St. Paulus - Nganjuk', 24),
          (236, 'St. Pius X - Blora', 25),
          (237, 'St. Paulus - Bojonegoro', 25),
          (238, 'St. Petrus - Tuban', 25),
          (239, 'St. Willibrodus - Cepu', 25),
          (240, 'St. Petrus Paulus - Rembang', 25),
          (241, 'St. Cornelius - Madiun', 26),
          (242, 'Mater Dei - Madiun', 26),
          (243, 'Regina Pacis _ Magetan', 26),
          (244, 'Santa Maria - Ponorogo', 26),
          (245, 'St. Hilarius - Klepu', 26),
          (246, 'St. Yosef - Ngawi', 26),
          (247, 'Kristus Raja - Ngrambe', 26),
          (248, 'St. Yusuf - Blitar', 27),
          (249, 'St. Maria - Blitar', 27),
          (250, 'St. Petrus & Paulus - Wlingi', 27),
          (251, 'Santa Maria Dengan Tidak Bernoda Asal - Tulungagung', 27),
          (252, 'St. Fransiskus Asisi - Resapombo', 27),
          (253, 'St. Fransiskus Asisi - Mojorejo', 27)
        ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, keuskupan_id = EXCLUDED.keuskupan_id;

        -- Seed user wilayah data (id, paroki_id, name)
        INSERT INTO wilayah (id, paroki_id, name) VALUES
          (1, 9, 'Wilayah Agnes'),
          (2, 9, 'Wilayah Anastasia'),
          (3, 198, 'Wilayah Andreas'),
          (4, 198, 'Wilayah Angela'),
          (11, 9, 'Wilayah Clara'),
          (12, 9, 'Wilayah Elizabeth'),
          (14, 9, 'Wilayah Fransiskus Xaverius'),
          (18, 9, 'Wilayah Lucia'),
          (20, 9, 'Wilayah Maria'),
          (22, 198, 'Wilayah Matius'),
          (23, 9, 'Wilayah Mikael'),
          (25, 198, 'Wilayah Petrus'),
          (27, 9, 'Wilayah Raphael'),
          (28, 9, 'Wilayah Sesilia'),
          (33, 9, 'Wilayah Ursula'),
          (34, 9, 'Wilayah Yohanes'),
          (47, 147, 'Wilayah Agatha'),
          (48, 147, 'Wilayah Yosafat Kunzewich'),
          (49, 147, 'Wilayah Soter'),
          (50, 147, 'Wilayah Filipus Neri'),
          (51, 147, 'Wilayah Kristoforus'),
          (52, 147, 'Wilayah Pius X'),
          (53, 147, 'Wilayah Sandjaja'),
          (54, 147, 'Wilayah Bonifasius'),
          (55, 147, 'Wilayah Markus'),
          (56, 147, 'Wilayah Padre Pio'),
          (57, 147, 'Wilayah Yulianus'),
          (58, 147, 'Wilayah Yustinus'),
          (59, 147, 'Wilayah Yohanes'),
          (60, 147, 'Wilayah Thomas Aquinas'),
          (61, 147, 'Wilayah Lukas'),
          (62, 147, 'Wilayah Antonius'),
          (63, 147, 'Wilayah Alexander'),
          (64, 147, 'Wilayah Cicilia'),
          (65, 147, 'Wilayah Petrus Kanisius'),
          (66, 147, 'Wilayah Gaudensius'),
          (67, 147, 'Wilayah Oscar Romero'),
          (68, 147, 'Wilayah Pedro Arrupe'),
          (69, 147, 'Wilayah Basilius'),
          (70, 147, 'Wilayah Herman Yosef'),
          (71, 147, 'Wilayah Leonardus'),
          (72, 147, 'Wilayah Maria'),
          (73, 147, 'Wilayah Dominicus'),
          (74, 157, 'Wilayah Theresia'),
          (75, 157, 'Wilayah Matheus'),
          (76, 157, 'Wilayah Yohanes'),
          (77, 157, 'Wilayah Maria'),
          (78, 157, 'Wilayah Yosep'),
          (79, 157, 'Wilayah Petrus'),
          (80, 157, 'Wilayah Paulus'),
          (81, 157, 'Wilayah Elizabeth'),
          (82, 134, 'Wilayah Duren Sawit Indah'),
          (83, 134, 'Wilayah Duren Sawit PTB'),
          (84, 134, 'Wilayah Duren Sawit Timur'),
          (85, 134, 'Wilayah Duren Sawit Baru'),
          (86, 134, 'Wilayah Duren Sawit Selatan'),
          (87, 134, 'Wilayah Pondok Bambu I'),
          (88, 134, 'Wilayah Pondok Bambu II'),
          (89, 134, 'Wilayah Klender'),
          (90, 134, 'Wilayah Buaran'),
          (91, 158, 'Wilayah Malaka Sari I'),
          (92, 158, 'Wilayah Malaka Sari II'),
          (93, 158, 'Wilayah Malaka Jaya I'),
          (94, 158, 'Wilayah Malaka Jaya II'),
          (95, 158, 'Wilayah Pondok Kopi I'),
          (96, 158, 'Wilayah Pondok Kopi II'),
          (97, 159, 'Wilayah Pondok Kelapa I'),
          (98, 159, 'Wilayah Pondok Kelapa II'),
          (99, 159, 'Wilayah Billy Moon'),
          (100, 159, 'Wilayah Bintara Jaya'),
          (9478, 4, 'Wilayah Kramat'),
          (9509, 2, 'Wilayah Cempaka Putih 1'),
          (9510, 2, 'Wilayah Cempaka Putih 2'),
          (9511, 2, 'Wilayah Cempaka Putih 3'),
          (9565, 4, 'Wilayah Kwitang'),
          (9566, 4, 'Wilayah Sentiong'),
          (9567, 4, 'Wilayah Paseban'),
          (9568, 4, 'Wilayah Johar Baru'),
          (9569, 4, 'Wilayah Percetakan Negara'),
          (9570, 4, 'Wilayah Rawasari'),
          (9819, 1, 'Wilayah Katedral')
        ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, paroki_id = EXCLUDED.paroki_id;

        -- Seed user lingkungan data (id, wilayah_id, name)
        INSERT INTO lingkungan (id, wilayah_id, name) VALUES
          (1, 1, 'Lingkungan Agnes 1'),
          (2, 1, 'Lingkungan Agnes 2'),
          (3, 1, 'Lingkungan Agnes 3'),
          (4, 2, 'Lingkungan Anastasia 1'),
          (5, 2, 'Lingkungan Anastasia 2'),
          (6, 2, 'Lingkungan Anastasia 3'),
          (7, 2, 'Lingkungan Anastasia 4'),
          (8, 2, 'Lingkungan Anastasia 5'),
          (9, 3, 'Lingkungan Andreas 1'),
          (10, 3, 'Lingkungan Andreas 2'),
          (11, 3, 'Lingkungan Andreas 3'),
          (12, 3, 'Lingkungan Andreas 4'),
          (13, 4, 'Lingkungan Angela 1'),
          (14, 4, 'Lingkungan Angela 2'),
          (15, 4, 'Lingkungan Angela 3'),
          (16, 4, 'Lingkungan Angela 4'),
          (43, 11, 'Lingkungan Clara 1'),
          (44, 11, 'Lingkungan Clara 2'),
          (45, 11, 'Lingkungan Clara 3'),
          (46, 11, 'Lingkungan Clara 4'),
          (47, 12, 'Lingkungan Elisabeth 1'),
          (48, 12, 'Lingkungan Elisabeth 2'),
          (49, 12, 'Lingkungan Elisabeth 3'),
          (52, 14, 'Lingkungan FX 1'),
          (53, 14, 'Lingkungan FX 2'),
          (54, 14, 'Lingkungan FX 3'),
          (55, 14, 'Lingkungan FX 4'),
          (64, 18, 'Lingkungan Lucia 1'),
          (65, 18, 'Lingkungan Lucia 2'),
          (66, 18, 'Lingkungan Lucia 3'),
          (67, 18, 'Lingkungan Lucia 4'),
          (72, 20, 'Lingkungan Maria 1'),
          (73, 20, 'Lingkungan Maria 2'),
          (74, 20, 'Lingkungan Maria 3'),
          (79, 22, 'Lingkungan Matius 1'),
          (80, 22, 'Lingkungan Matius 2'),
          (81, 22, 'Lingkungan Matius 3'),
          (82, 22, 'Lingkungan Matius 4'),
          (83, 23, 'Lingkungan Mikael 1'),
          (84, 23, 'Lingkungan Mikael 2'),
          (90, 25, 'Lingkungan Petrus 1'),
          (91, 25, 'Lingkungan Petrus 2'),
          (92, 25, 'Lingkungan Petrus 3'),
          (93, 25, 'Lingkungan Petrus 4'),
          (94, 25, 'Lingkungan Petrus 5'),
          (99, 27, 'Lingkungan Raphael 1'),
          (100, 27, 'Lingkungan Raphael 2'),
          (101, 27, 'Lingkungan Raphael 3'),
          (102, 27, 'Lingkungan Raphael 4'),
          (103, 28, 'Lingkungan Sesilia 1'),
          (104, 28, 'Lingkungan Sesilia 2'),
          (105, 28, 'Lingkungan Sesilia 3'),
          (106, 28, 'Lingkungan Sesilia 4'),
          (124, 33, 'Lingkungan Ursula 1'),
          (125, 33, 'Lingkungan Ursula 2'),
          (126, 33, 'Lingkungan Ursula 3'),
          (127, 34, 'Lingkungan Yohanes 1'),
          (128, 34, 'Lingkungan Yohanes 2'),
          (129, 34, 'Lingkungan Yohanes 3'),
          (130, 34, 'Lingkungan Yohanes 4'),
          (131, 9819, 'Lingkungan St. Maria Goretti '),
          (132, 9819, 'Lingkungan St. Gabriel Posenti'),
          (133, 9819, 'Lingkungan St. Dominikus Savio'),
          (134, 9509, 'Lingkungan St. Yakobus Alfeus'),
          (135, 9509, 'Lingkungan St. Simon'),
          (136, 9509, 'Lingkungan St. Stefanus'),
          (137, 9509, 'Lingkungan St. Thadeus'),
          (138, 9510, 'Lingkungan St. Filipus'),
          (139, 9510, 'Lingkungan St. Bartolomeus'),
          (140, 9510, 'Lingkungan St. Matias'),
          (141, 9510, 'Lingkungan St. Thomas'),
          (142, 9511, 'Lingkungan SPM Bunda Pengantara Rahmat'),
          (143, 9511, 'Lingkungan SPM Penolong Umat Kristiani'),
          (144, 9511, 'Lingkungan SPM Bunda Penolong Abadi'),
          (145, 9511, 'Lingkungan SPM Bunda Pengharapan'),
          (146, 9478, 'Lingkungan St. Petrus (Kalipasir)'),
          (147, 9478, 'Lingkungan St. Yakobus Zebedeus (Kramat 5,6,7)'),
          (148, 9478, 'Lingkungan St. Yohanes (Kenari)'),
          (149, 9478, 'Lingkungan St. Faustina (Cikini)'),
          (150, 9478, 'Lingkungan St. Padre Pio (Pegangsaan)'),
          (151, 9565, 'Lingkungan St. Bonaventura (Kwitang Kembang)'),
          (152, 9565, 'Lingkungan St. Bernadette (Kwitang 3)'),
          (153, 9565, 'Lingkungan St. Bernardus (Kramat 1,2)'),
          (154, 9565, 'Lingkungan St. Benedictus (Kramat 3,4)'),
          (155, 9566, 'Lingkungan St. Clara (Kembang Sepatu)'),
          (156, 9566, 'Lingkungan St. Claudia (Kramat Pulo)'),
          (157, 9567, 'Lingkungan St. Fransiskus Asisi (Paseban)'),
          (158, 9567, 'Lingkungan St. Bernardinus (Sentiong)'),
          (159, 9567, 'Lingkungan St. Angela Merici (Kawi Kawi)'),
          (160, 9567, 'Lingkungan St. Agustinus (Salemba)'),
          (161, 9568, 'Lingkungan St. Helena (Kramat Jaya Baru Blok D&E)'),
          (162, 9568, 'Lingkungan St. Emilia (Kramat Jaya Baru Blok H)'),
          (163, 9568, 'Lingkungan St. Elisabeth (Kramat Jaya Baru Blok F)'),
          (164, 9568, 'Lingkungan St. Antonius (Kramat Jaya Baru Blok G)'),
          (165, 9569, 'Lingkungan St. Matius (Percetakan Negara)'),
          (166, 9569, 'Lingkungan St. Markus (Johar Baru Kawi Kawi)'),
          (167, 9569, 'Lingkungan St. Martinus (Johar Baru Utara)'),
          (168, 9570, 'Lingkungan St. Gabriel (Rawasari Timur)'),
          (169, 9570, 'Lingkungan St. Raphael (Green Pramuka)'),
          (170, 9570, 'Lingkungan St. Mikael (Cempaka Putih Barat)'),
          (171, 9570, 'Lingkungan St. Uriel (Rawasari)')
        ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, wilayah_id = EXCLUDED.wilayah_id;

        INSERT INTO ordo (id, code, name) VALUES
          (1, 'SJ', 'SJ - Serikat Yesus (Jesuit)'),
          (2, 'OFM', 'OFM - Fransiskan'),
          (3, 'OFM Cap', 'OFM Cap - Fransiskan Kapusin'),
          (4, 'MSF', 'MSF - Misionaris Keluarga Kudus'),
          (5, 'SVD', 'SVD - Serikat Sabda Allah'),
          (6, 'CSsR', 'CSsR - Kongregasi Sang Penebus'),
          (7, 'O.Carm', 'O.Carm - Ordo Karmel'),
          (8, 'SCJ', 'SCJ - Hati Kudus Yesus')
        ON CONFLICT (code) DO NOTHING;
      `);
    } catch (e) {
      console.log('Auto-migration user_profiles notice:', e);
    }
  }

  @Get('roles')
  @ApiOperation({
    summary: 'Ambil Daftar Role Akun dari Database',
    description: 'Mengembalikan daftar 3 role utama: Umat, Romo Paroki, dan Romo Ordo.',
  })
  async getRoles() {
    const roles = await this.dataSource.query(
      `SELECT id, code, name FROM roles WHERE code IN ('UMAT', 'ROMO_PAROKI', 'ROMO_ORDO') ORDER BY id ASC`,
    );
    return roles.map((r) => {
      let displayName = r.name;
      if (r.code === 'UMAT') {
        displayName = 'Umat';
      } else if (r.code === 'ROMO_PAROKI') {
        displayName = 'Romo Paroki';
      } else if (r.code === 'ROMO_ORDO') {
        displayName = 'Romo Ordo';
      }
      return { id: r.id, code: r.code, name: displayName, label: displayName };
    });
  }

  @Get('keuskupan')
  @ApiOperation({ summary: 'Ambil Daftar Keuskupan dari Database' })
  async getKeuskupan() {
    return await this.dataSource.query('SELECT id, name FROM keuskupan ORDER BY id ASC');
  }

  @Get('paroki')
  @ApiOperation({ summary: 'Ambil Daftar Paroki berdasarkan Keuskupan ID dari Database' })
  async getParoki(@Query('keuskupanId') keuskupanId?: number) {
    if (keuskupanId) {
      return await this.dataSource.query('SELECT id, keuskupan_id, name FROM paroki WHERE keuskupan_id = $1 ORDER BY id ASC', [keuskupanId]);
    }
    return await this.dataSource.query('SELECT id, keuskupan_id, name FROM paroki ORDER BY id ASC');
  }

  @Get('wilayah')
  @ApiOperation({ summary: 'Ambil Daftar Wilayah berdasarkan Paroki ID dari Database' })
  async getWilayah(@Query('parokiId') parokiId?: number) {
    if (parokiId) {
      return await this.dataSource.query('SELECT id, paroki_id, name FROM wilayah WHERE paroki_id = $1 ORDER BY id ASC', [parokiId]);
    }
    return await this.dataSource.query('SELECT id, paroki_id, name FROM wilayah ORDER BY id ASC');
  }

  @Get('lingkungan')
  @ApiOperation({ summary: 'Ambil Daftar Lingkungan berdasarkan Wilayah ID dari Database' })
  async getLingkungan(@Query('wilayahId') wilayahId?: number) {
    if (wilayahId) {
      return await this.dataSource.query('SELECT id, wilayah_id, name FROM lingkungan WHERE wilayah_id = $1 ORDER BY id ASC', [wilayahId]);
    }
    return await this.dataSource.query('SELECT id, wilayah_id, name FROM lingkungan ORDER BY id ASC');
  }

  @Get('provinsi')
  @ApiOperation({ summary: 'Ambil Daftar Provinsi dari Database' })
  async getProvinsi() {
    return await this.dataSource.query('SELECT id, name FROM provinsi ORDER BY id ASC');
  }

  @Get('kabupaten-kota')
  @ApiOperation({ summary: 'Ambil Daftar Kabupaten/Kota berdasarkan Provinsi ID dari Database' })
  async getKabupatenKota(@Query('provinsiId') provinsiId?: number) {
    if (provinsiId) {
      return await this.dataSource.query(
        'SELECT id, provinsi_id, name, type FROM kabupaten_kota WHERE provinsi_id = $1 ORDER BY id ASC',
        [provinsiId],
      );
    }
    return await this.dataSource.query('SELECT id, provinsi_id, name, type FROM kabupaten_kota ORDER BY id ASC');
  }

  @Get('ordo')
  @ApiOperation({ summary: 'Ambil Daftar Ordo / Kongregasi dari Database' })
  async getOrdo() {
    return await this.dataSource.query('SELECT id, code, name FROM ordo ORDER BY id ASC');
  }

  @Get('check-status')
  @ApiOperation({ summary: 'Cek Status Akun Terbaru Berdasarkan Nomor HP' })
  async checkAccountStatus(@Query('phone') phone: string) {
    if (!phone) return { statusCode: 400, message: 'Nomor HP wajib disertakan' };
    let cleanPhone = phone.trim();
    if (cleanPhone.startsWith('0')) cleanPhone = cleanPhone.substring(1);
    if (cleanPhone.startsWith('+62')) cleanPhone = cleanPhone.substring(3);
    if (cleanPhone.startsWith('62')) cleanPhone = cleanPhone.substring(2);
    const fullPhone = `62${cleanPhone}`;

    const users = await this.dataSource.query(
      `SELECT u.id, u.uuid, u.phone_number, u.account_status, r.code as role_code,
              p.full_name, p.email, p.birth_date, p.address, p.avatar_url, p.keuskupan_id, p.paroki_id, p.wilayah_id, p.lingkungan_id, p.ordo_id, p.kabupaten_kota_id, kk.provinsi_id,
              k.name as keuskupan_name, par.name as paroki_name, w.name as wilayah_name, l.name as lingkungan_name, ord.name as ordo_name, kk.name as kota_name,
              p.pengurus_position, p.romo_position, p.jabatan_start_year, p.jabatan_end_year, p.jabatan_start_date, p.jabatan_end_date, p.is_jabatan_active
       FROM auth_users u
       JOIN roles r ON u.role_id = r.id
       JOIN user_profiles p ON p.user_id = u.id
       LEFT JOIN keuskupan k ON p.keuskupan_id = k.id
       LEFT JOIN paroki par ON p.paroki_id = par.id
       LEFT JOIN wilayah w ON p.wilayah_id = w.id
       LEFT JOIN lingkungan l ON p.lingkungan_id = l.id
       LEFT JOIN ordo ord ON p.ordo_id = ord.id
       LEFT JOIN kabupaten_kota kk ON p.kabupaten_kota_id = kk.id
       WHERE u.phone_number = $1`,
      [fullPhone],
    );

    if (!users.length) {
      return { statusCode: 404, message: 'Akun tidak ditemukan' };
    }

    const user = users[0];
    return {
      statusCode: 200,
      accountStatus: user.account_status,
      user: {
        id: user.id,
        uuid: user.uuid,
        fullName: user.full_name,
        phoneNumber: user.phone_number,
        email: user.email,
        birthDate: user.birth_date,
        address: user.address,
        avatarUrl: user.avatar_url,
        roleCode: user.role_code,
        accountStatus: user.account_status,
        keuskupanId: user.keuskupan_id,
        parokiId: user.paroki_id,
        wilayahId: user.wilayah_id,
        lingkunganId: user.lingkungan_id,
        ordoId: user.ordo_id,
        kabupatenKotaId: user.kabupaten_kota_id,
        provinsiId: user.provinsi_id,
        keuskupanName: user.keuskupan_name,
        parokiName: user.paroki_name,
        wilayahName: user.wilayah_name,
        lingkunganName: user.lingkungan_name,
        ordoName: user.ordo_name,
        kabupatenKotaName: user.kota_name,
        pengurusPosition: user.pengurus_position,
        romoPosition: user.romo_position,
        jabatanStartYear: user.jabatan_start_year,
        jabatanEndYear: user.jabatan_end_year,
        jabatanStartDate: user.jabatan_start_date,
        jabatanEndDate: user.jabatan_end_date,
        isJabatanActive: user.is_jabatan_active !== null ? user.is_jabatan_active : false,
      },
    };
  }

  @Get('pengurus/pending-umat')
  @ApiOperation({ summary: 'Daftar Umat Baru yang Menunggu Persetujuan Pengurus Lingkungan / Koordinator Keuskupan' })
  async getPengurusPendingUmat(
    @Query('lingkunganId') lingkunganId?: string,
    @Query('keuskupanId') keuskupanId?: string,
    @Query('pengurusUserId') pengurusUserId?: string,
  ) {
    let resolvedLingkunganId = lingkunganId ? parseInt(lingkunganId, 10) : null;
    let resolvedKeuskupanId = keuskupanId ? parseInt(keuskupanId, 10) : null;
    let isKoordinator = false;

    if (pengurusUserId) {
      const p = await this.dataSource.query(
        'SELECT lingkungan_id, keuskupan_id, pengurus_position FROM user_profiles WHERE user_id = $1',
        [parseInt(pengurusUserId, 10)],
      );
      if (p.length > 0) {
        const pos = (p[0].pengurus_position || '').toString().toLowerCase();
        if (pos.includes('koordinator')) {
          isKoordinator = true;
          if (!resolvedKeuskupanId && p[0].keuskupan_id) resolvedKeuskupanId = p[0].keuskupan_id;
        } else {
          if (!resolvedLingkunganId && p[0].lingkungan_id) resolvedLingkunganId = p[0].lingkungan_id;
        }
      }
    }

    if (resolvedKeuskupanId || isKoordinator) {
      const targetKeuskupan = resolvedKeuskupanId || 1;
      const rows = await this.dataSource.query(
        `SELECT u.id, u.uuid, u.phone_number, u.account_status, u.created_at,
                p.full_name, p.email, p.birth_date, p.address, p.avatar_url,
                k.name as keuskupan_name, par.name as paroki_name, w.name as wilayah_name, l.name as lingkungan_name,
                kk.name as kota_name
         FROM auth_users u
         JOIN roles r ON u.role_id = r.id
         JOIN user_profiles p ON p.user_id = u.id
         LEFT JOIN keuskupan k ON p.keuskupan_id = k.id
         LEFT JOIN paroki par ON p.paroki_id = par.id
         LEFT JOIN wilayah w ON p.wilayah_id = w.id
         LEFT JOIN lingkungan l ON p.lingkungan_id = l.id
         LEFT JOIN kabupaten_kota kk ON p.kabupaten_kota_id = kk.id
         WHERE r.code = 'UMAT'
           AND u.account_status = 'PENDING_APPROVAL'
           AND (p.pengurus_position IS NULL OR LOWER(p.pengurus_position) NOT LIKE '%koordinator%')
           AND p.keuskupan_id = $1
         ORDER BY u.created_at DESC`,
        [targetKeuskupan],
      );
      return rows;
    }

    if (!resolvedLingkunganId) {
      const rows = await this.dataSource.query(
        `SELECT u.id, u.uuid, u.phone_number, u.account_status, u.created_at,
                p.full_name, p.email, p.birth_date, p.address, p.avatar_url,
                k.name as keuskupan_name, par.name as paroki_name, w.name as wilayah_name, l.name as lingkungan_name,
                kk.name as kota_name
         FROM auth_users u
         JOIN roles r ON u.role_id = r.id
         JOIN user_profiles p ON u.id = p.user_id
         LEFT JOIN keuskupan k ON p.keuskupan_id = k.id
         LEFT JOIN paroki par ON p.paroki_id = par.id
         LEFT JOIN wilayah w ON p.wilayah_id = w.id
         LEFT JOIN lingkungan l ON p.lingkungan_id = l.id
         LEFT JOIN kabupaten_kota kk ON p.kabupaten_kota_id = kk.id
         WHERE r.code = 'UMAT'
           AND u.account_status = 'PENDING_APPROVAL'
           AND (p.pengurus_position IS NULL OR LOWER(p.pengurus_position) NOT LIKE '%koordinator%')
         ORDER BY u.created_at DESC`,
      );
      return rows;
    }

    const rows = await this.dataSource.query(
      `SELECT u.id, u.uuid, u.phone_number, u.account_status, u.created_at,
              p.full_name, p.email, p.birth_date, p.address, p.avatar_url,
              k.name as keuskupan_name, par.name as paroki_name, w.name as wilayah_name, l.name as lingkungan_name,
              kk.name as kota_name
       FROM auth_users u
       JOIN roles r ON u.role_id = r.id
       JOIN user_profiles p ON p.user_id = u.id
       LEFT JOIN keuskupan k ON p.keuskupan_id = k.id
       LEFT JOIN paroki par ON p.paroki_id = par.id
       LEFT JOIN wilayah w ON p.wilayah_id = w.id
       LEFT JOIN lingkungan l ON p.lingkungan_id = l.id
       LEFT JOIN kabupaten_kota kk ON p.kabupaten_kota_id = kk.id
       WHERE r.code = 'UMAT'
         AND u.account_status = 'PENDING_APPROVAL'
         AND (p.pengurus_position IS NULL OR LOWER(p.pengurus_position) NOT LIKE '%koordinator%')
         AND p.lingkungan_id = $1
       ORDER BY u.created_at DESC`,
      [resolvedLingkunganId],
    );
    return rows;
  }

  @Post('pengurus/process-approval')
  @ApiOperation({ summary: 'Proses Persetujuan Umat oleh Pengurus Lingkungan' })
  async processPengurusApproval(
    @Body() body: { targetUserId: number; approverUserId: number; action: 'APPROVE' | 'REJECT'; rejectionReason?: string },
  ) {
    const { targetUserId, approverUserId, action, rejectionReason } = body;
    if (!targetUserId || !approverUserId || !action) {
      throw new BadRequestException('Parameter targetUserId, approverUserId, dan action wajib diisi.');
    }

    const newStatus = action === 'APPROVE' ? 'APPROVED' : 'REJECTED';
    await this.dataSource.query(
      'UPDATE auth_users SET account_status = $1, updated_at = CURRENT_TIMESTAMP WHERE id = $2',
      [newStatus, targetUserId],
    );

    await this.dataSource.query(
      `INSERT INTO user_approvals (target_user_id, approver_user_id, action, rejection_reason)
       VALUES ($1, $2, $3, $4)`,
      [targetUserId, approverUserId, action, rejectionReason || null],
    );

    return {
      statusCode: 200,
      message: action === 'APPROVE' ? 'Umat berhasil disetujui!' : 'Pendaftaran umat berhasil ditolak.',
      accountStatus: newStatus,
    };
  }

  @Get('romo/pending-romo')
  @ApiOperation({ summary: 'Daftar Romo Baru yang Menunggu Persetujuan Kepala Romo Paroki / Ketua Romo Ordo' })
  async getRomoPendingRomo(
    @Query('romoUserId') romoUserId?: string,
    @Query('parokiId') parokiId?: string,
    @Query('ordoId') ordoId?: string,
  ) {
    let resolvedParokiId = parokiId ? parseInt(parokiId, 10) : null;
    let resolvedOrdoId = ordoId ? parseInt(ordoId, 10) : null;
    let isOrdo = false;

    if (romoUserId) {
      const p = await this.dataSource.query(
        `SELECT p.paroki_id, p.ordo_id, r.code as role_code, p.romo_position
         FROM user_profiles p
         JOIN auth_users u ON p.user_id = u.id
         JOIN roles r ON u.role_id = r.id
         WHERE p.user_id = $1`,
        [parseInt(romoUserId, 10)],
      );
      if (p.length > 0) {
        if (p[0].role_code === 'ROMO_ORDO') isOrdo = true;
        if (p[0].paroki_id) resolvedParokiId = p[0].paroki_id;
        if (p[0].ordo_id) resolvedOrdoId = p[0].ordo_id;
      }
    }

    if (isOrdo || resolvedOrdoId) {
      const rows = await this.dataSource.query(
        `SELECT u.id, u.uuid, u.phone_number, u.account_status, u.created_at,
                p.full_name, p.email, p.birth_date, p.address, p.avatar_url,
                p.romo_position, o.name as ordo_name, o.code as ordo_code,
                k.name as keuskupan_name, par.name as paroki_name,
                kk.name as kota_name
         FROM auth_users u
         JOIN roles r ON u.role_id = r.id
         JOIN user_profiles p ON u.id = p.user_id
         LEFT JOIN ordo o ON (p.ordo_id = o.id OR p.user_id IN (SELECT rp.user_id FROM romo_profiles rp WHERE rp.ordo_id = o.id))
         LEFT JOIN keuskupan k ON p.keuskupan_id = k.id
         LEFT JOIN paroki par ON p.paroki_id = par.id
         LEFT JOIN kabupaten_kota kk ON p.kabupaten_kota_id = kk.id
         WHERE r.code = 'ROMO_ORDO'
           AND u.account_status = 'PENDING_APPROVAL'
           AND ($1::int IS NULL OR p.ordo_id = $1::int OR p.user_id IN (SELECT rp.user_id FROM romo_profiles rp WHERE rp.ordo_id = $1::int))
         ORDER BY u.created_at DESC`,
        [resolvedOrdoId],
      );
      return rows;
    } else {
      const rows = await this.dataSource.query(
        `SELECT u.id, u.uuid, u.phone_number, u.account_status, u.created_at,
                p.full_name, p.email, p.birth_date, p.address, p.avatar_url,
                p.romo_position,
                k.name as keuskupan_name, par.name as paroki_name,
                kk.name as kota_name
         FROM auth_users u
         JOIN roles r ON u.role_id = r.id
         JOIN user_profiles p ON u.id = p.user_id
         LEFT JOIN keuskupan k ON p.keuskupan_id = k.id
         LEFT JOIN paroki par ON p.paroki_id = par.id
         LEFT JOIN kabupaten_kota kk ON p.kabupaten_kota_id = kk.id
         WHERE r.code = 'ROMO_PAROKI'
           AND u.account_status = 'PENDING_APPROVAL'
           AND ($1::int IS NULL OR p.paroki_id = $1::int)
         ORDER BY u.created_at DESC`,
        [resolvedParokiId],
      );
      return rows;
    }
  }

  @Post('romo/process-approval')
  @ApiOperation({ summary: 'Proses Persetujuan Romo oleh Kepala Romo Paroki / Ketua Romo Ordo' })
  async processRomoApproval(
    @Body() body: { targetUserId: number; approverUserId: number; action: 'APPROVE' | 'REJECT'; rejectionReason?: string },
  ) {
    const { targetUserId, approverUserId, action, rejectionReason } = body;
    if (!targetUserId || !approverUserId || !action) {
      throw new BadRequestException('Parameter targetUserId, approverUserId, dan action wajib diisi.');
    }

    const newStatus = action === 'APPROVE' ? 'APPROVED' : 'REJECTED';
    await this.dataSource.query(
      'UPDATE auth_users SET account_status = $1, updated_at = CURRENT_TIMESTAMP WHERE id = $2',
      [newStatus, targetUserId],
    );

    await this.dataSource.query(
      `INSERT INTO user_approvals (target_user_id, approver_user_id, action, rejection_reason)
       VALUES ($1, $2, $3, $4)`,
      [targetUserId, approverUserId, action, rejectionReason || null],
    );

    return {
      statusCode: 200,
      message: action === 'APPROVE' ? 'Romo berhasil disetujui!' : 'Pendaftaran Romo berhasil ditolak.',
      accountStatus: newStatus,
    };
  }

  @Post('register')
  @ApiOperation({
    summary: 'Registrasi User Baru (Terpisah Antara auth_users & user_profiles)',
    description:
      'Registrasi user baru. Kredensial login masuk ke auth_users, sedangkan biodata & domisili masuk ke user_profiles. Notifikasi approval dikirim berjenjang.',
  })
  @ApiResponse({ status: 201, description: 'Registrasi berhasil, akun berstatus PENDING_APPROVAL.', type: RegisterResponseDto })
  async register(@Body() dto: RegisterUserDto) {
    const queryRunner = this.dataSource.createQueryRunner();
    await queryRunner.connect();
    await queryRunner.startTransaction();

    try {
      const role = await queryRunner.query('SELECT id FROM roles WHERE code = $1', [dto.roleCode]);
      const roleId = role[0]?.id || 1;

      // Romo Position only applies to Romo roles (ROMO_PAROKI / ROMO_ORDO)
      const isRomo = dto.roleCode === RoleCodeEnum.ROMO_PAROKI || dto.roleCode === RoleCodeEnum.ROMO_ORDO || (dto.roleCode as string).startsWith('ROMO');
      const pengurusPositionVal = (dto.pengurusPosition && dto.pengurusPosition.trim() !== '') ? dto.pengurusPosition : null;
      const romoPositionVal = isRomo ? ((dto.romoPosition && dto.romoPosition.trim() !== '') ? dto.romoPosition : 'ROMO_BIASA') : null;

      let approverName = 'Admin Aplikasi CATU';
      let assignedApproverId: number | null = null;
      const isKoordinatorRegistration = (pengurusPositionVal && pengurusPositionVal.toLowerCase().includes('koordinator')) || (dto.roleCode as string) === 'KOORDINATOR';

      if (dto.roleCode === RoleCodeEnum.UMAT && dto.lingkunganId && !isKoordinatorRegistration) {
        const pengurus = await queryRunner.query(
          `SELECT u.id, p.full_name, u.phone_number
           FROM user_profiles p
           JOIN auth_users u ON p.user_id = u.id
           JOIN roles r ON u.role_id = r.id
           WHERE p.lingkungan_id = $1
             AND (r.code = 'PENGURUS_LINGKUNGAN' OR p.pengurus_position IS NOT NULL)
             AND u.account_status = 'APPROVED'
           ORDER BY CASE WHEN LOWER(p.pengurus_position) LIKE '%ketua%' THEN 1 ELSE 2 END
           LIMIT 1`,
          [dto.lingkunganId],
        );
        if (pengurus.length > 0) {
          assignedApproverId = pengurus[0].id;
          approverName = `${pengurus[0].full_name} (${pengurus[0].phone_number})`;
        }
      } else if (dto.roleCode === 'ROMO_PAROKI' && romoPositionVal !== 'KETUA_ROMO' && dto.parokiId) {
        const ketuaRomo = await queryRunner.query(
          `SELECT u.id, p.full_name, u.phone_number
           FROM user_profiles p
           JOIN auth_users u ON p.user_id = u.id
           JOIN roles r ON u.role_id = r.id
           WHERE p.paroki_id = $1
             AND r.code = 'ROMO_PAROKI'
             AND p.romo_position = 'KETUA_ROMO'
             AND u.account_status = 'APPROVED'
           LIMIT 1`,
          [dto.parokiId],
        );
        if (ketuaRomo.length > 0) {
          assignedApproverId = ketuaRomo[0].id;
          approverName = `Kepala Romo Paroki: ${ketuaRomo[0].full_name} (${ketuaRomo[0].phone_number})`;
        }
      } else if (dto.roleCode === 'ROMO_ORDO' && romoPositionVal !== 'KETUA_ROMO' && dto.ordoId) {
        const ketuaOrdo = await queryRunner.query(
          `SELECT u.id, p.full_name, u.phone_number
           FROM user_profiles p
           JOIN auth_users u ON p.user_id = u.id
           JOIN roles r ON u.role_id = r.id
           WHERE (p.ordo_id = $1 OR p.user_id IN (SELECT rp.user_id FROM romo_profiles rp WHERE rp.ordo_id = $1))
             AND r.code = 'ROMO_ORDO'
             AND p.romo_position = 'KETUA_ROMO'
             AND u.account_status = 'APPROVED'
           LIMIT 1`,
          [dto.ordoId],
        );
        if (ketuaOrdo.length > 0) {
          assignedApproverId = ketuaOrdo[0].id;
          approverName = `Ketua Romo Ordo: ${ketuaOrdo[0].full_name} (${ketuaOrdo[0].phone_number})`;
        }
      }

      // Hash password dengan Bcrypt salt 10
      const hashedPassword = await bcrypt.hash(dto.password, 10);

      // Check if position already taken for that Lingkungan
      if ((dto.roleCode === 'PENGURUS_LINGKUNGAN' || pengurusPositionVal) && dto.lingkunganId && pengurusPositionVal) {
        const existingPengurus = await queryRunner.query(
          `SELECT u.id, p.full_name, p.pengurus_position, u.account_status
           FROM user_profiles p
           JOIN auth_users u ON p.user_id = u.id
           WHERE p.lingkungan_id = $1
             AND u.account_status IN ('APPROVED', 'PENDING_APPROVAL')
             AND (
               LOWER(p.pengurus_position) = LOWER($2)
               OR (LOWER($2) LIKE '%ketua%' AND LOWER($2) NOT LIKE '%wakil%' AND LOWER(p.pengurus_position) LIKE '%ketua%' AND LOWER(p.pengurus_position) NOT LIKE '%wakil%')
               OR (LOWER($2) LIKE '%wakil%' AND LOWER(p.pengurus_position) LIKE '%wakil%')
               OR (LOWER($2) LIKE '%sekretaris%' AND LOWER(p.pengurus_position) LIKE '%sekretaris%')
               OR (LOWER($2) LIKE '%bendahara%' AND LOWER(p.pengurus_position) LIKE '%bendahara%')
             )`,
          [dto.lingkunganId, pengurusPositionVal],
        );
        if (existingPengurus.length > 0) {
          const existingName = existingPengurus[0].full_name;
          const existingPos = existingPengurus[0].pengurus_position;
          throw new BadRequestException(
            `Jabatan ${pengurusPositionVal} untuk lingkungan ini sudah terisi / diajukan oleh ${existingName} (${existingPos}). Pengurus dengan jabatan yang sama tidak boleh ganda dalam satu lingkungan.`,
          );
        }
      }

      // Flag Jabatan applies ONLY to leadership positions. Ordinary Umat & ordinary Romo have NO leadership position (null).
      const isLeadershipPos = Boolean(pengurusPositionVal || (isRomo && romoPositionVal === 'KETUA_ROMO'));
      const initialActiveFlag = isLeadershipPos ? false : null;

      // Extract years from dates if missing
      let startYear = dto.jabatanStartYear;
      let endYear = dto.jabatanEndYear;
      if (!startYear && dto.jabatanStartDate && dto.jabatanStartDate.includes('/')) {
        const parts = dto.jabatanStartDate.split('/');
        if (parts.length === 3) startYear = parseInt(parts[2], 10);
      }
      if (!endYear && dto.jabatanEndDate && dto.jabatanEndDate.includes('/')) {
        const parts = dto.jabatanEndDate.split('/');
        if (parts.length === 3) endYear = parseInt(parts[2], 10);
      }

      // 1. Insert ke auth_users
      const authResult = await queryRunner.query(
        `INSERT INTO auth_users (phone_number, password_hash, role_id, account_status, approval_assigned_to_user_id)
         VALUES ($1, $2, $3, 'PENDING_APPROVAL', $4) RETURNING id, uuid, phone_number, account_status`,
        [dto.phoneNumber, hashedPassword, roleId, assignedApproverId],
      );
      const authUser = authResult[0];

      // 2. Insert ke user_profiles
      await queryRunner.query(
        `INSERT INTO user_profiles (user_id, full_name, email, birth_date, address, keuskupan_id, paroki_id, wilayah_id, lingkungan_id, kabupaten_kota_id, pengurus_position, romo_position, jabatan_start_year, jabatan_end_year, jabatan_start_date, jabatan_end_date, is_jabatan_active, ordo_id)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18)`,
        [
          authUser.id,
          dto.fullName,
          dto.email || null,
          dto.birthDate || null,
          dto.address || null,
          dto.keuskupanId || null,
          dto.parokiId || null,
          dto.wilayahId || null,
          dto.lingkunganId || null,
          dto.kabupatenKotaId || 3175,
          pengurusPositionVal,
          romoPositionVal,
          startYear || null,
          endYear || null,
          dto.jabatanStartDate || null,
          dto.jabatanEndDate || null,
          initialActiveFlag,
          dto.ordoId || null,
        ],
      );

      await queryRunner.commitTransaction();

      // Detailed location names for response DTO
      let keuskupanName = '';
      let parokiName = '';
      let wilayahName = '';
      let lingkunganName = '';
      let ordoName = '';
      let kabupatenKotaName = 'JAKARTA TIMUR';

      if (dto.keuskupanId) {
        const kRes = await this.dataSource.query('SELECT name FROM keuskupan WHERE id = $1', [dto.keuskupanId]);
        if (kRes.length > 0) keuskupanName = kRes[0].name;
      }
      if (dto.parokiId) {
        const pRes = await this.dataSource.query('SELECT name FROM paroki WHERE id = $1', [dto.parokiId]);
        if (pRes.length > 0) parokiName = pRes[0].name;
      }
      if (dto.wilayahId) {
        const wRes = await this.dataSource.query('SELECT name FROM wilayah WHERE id = $1', [dto.wilayahId]);
        if (wRes.length > 0) wilayahName = wRes[0].name;
      }
      if (dto.lingkunganId) {
        const lRes = await this.dataSource.query('SELECT name FROM lingkungan WHERE id = $1', [dto.lingkunganId]);
        if (lRes.length > 0) lingkunganName = lRes[0].name;
      }
      if (dto.ordoId) {
        const oRes = await this.dataSource.query('SELECT name FROM ordo WHERE id = $1', [dto.ordoId]);
        if (oRes.length > 0) ordoName = oRes[0].name;
      }

      if (dto.roleCode === 'UMAT' && dto.lingkunganId) {
        const pengurusUsers = await this.dataSource.query(
          `SELECT u.id FROM auth_users u
           JOIN user_profiles p ON u.id = p.user_id
           JOIN roles r ON u.role_id = r.id
           WHERE p.lingkungan_id = $1
             AND (r.code = 'PENGURUS_LINGKUNGAN' OR p.pengurus_position IS NOT NULL)
             AND u.account_status = 'APPROVED'`,
          [dto.lingkunganId],
        );

        for (const pg of pengurusUsers) {
          try {
            await this.dataSource.query(
              `INSERT INTO notifications (user_id, title, body, type)
               VALUES ($1, $2, $3, 'NEW_ORDER_MONITOR')`,
              [
                pg.id,
                `Pendaftaran Umat Baru: ${dto.fullName}`,
                `Umat baru ${dto.fullName} (${dto.phoneNumber}) telah mendaftar di ${lingkunganName || 'Lingkungan Anda'} dan menunggu persetujuan (approval).`,
              ],
            );
          } catch (_) {}
        }
      } else if (dto.roleCode === 'ROMO_PAROKI' && romoPositionVal !== 'KETUA_ROMO' && dto.parokiId) {
        const ketuaRomoUsers = await this.dataSource.query(
          `SELECT u.id FROM auth_users u
           JOIN user_profiles p ON u.id = p.user_id
           JOIN roles r ON u.role_id = r.id
           WHERE p.paroki_id = $1
             AND r.code = 'ROMO_PAROKI'
             AND p.romo_position = 'KETUA_ROMO'
             AND u.account_status = 'APPROVED'`,
          [dto.parokiId],
        );

        for (const kr of ketuaRomoUsers) {
          try {
            await this.dataSource.query(
              `INSERT INTO notifications (user_id, title, body, type)
               VALUES ($1, $2, $3, 'NEW_ORDER_MONITOR')`,
              [
                kr.id,
                `Pendaftaran Romo Paroki Baru: ${dto.fullName}`,
                `Romo ${dto.fullName} (${dto.phoneNumber}) mendaftar di paroki Anda (${parokiName || 'Paroki'}) dan menunggu persetujuan (approval).`,
              ],
            );
          } catch (_) {}
        }
      } else if (dto.roleCode === 'ROMO_ORDO' && romoPositionVal !== 'KETUA_ROMO' && dto.ordoId) {
        let ordoName = '';
        const ordoRes = await this.dataSource.query('SELECT name FROM ordo WHERE id = $1', [dto.ordoId]);
        if (ordoRes.length > 0) ordoName = ordoRes[0].name;

        const ketuaOrdoUsers = await this.dataSource.query(
          `SELECT u.id FROM auth_users u
           JOIN user_profiles p ON u.id = p.user_id
           JOIN roles r ON u.role_id = r.id
           WHERE (p.ordo_id = $1 OR p.user_id IN (SELECT rp.user_id FROM romo_profiles rp WHERE rp.ordo_id = $1))
             AND r.code = 'ROMO_ORDO'
             AND p.romo_position = 'KETUA_ROMO'
             AND u.account_status = 'APPROVED'`,
          [dto.ordoId],
        );

        for (const ko of ketuaOrdoUsers) {
          try {
            await this.dataSource.query(
              `INSERT INTO notifications (user_id, title, body, type)
               VALUES ($1, $2, $3, 'NEW_ORDER_MONITOR')`,
              [
                ko.id,
                `Pendaftaran Romo Ordo Baru: ${dto.fullName}`,
                `Romo ${dto.fullName} (${dto.phoneNumber}) mendaftar di ordo Anda (${ordoName || 'Ordo'}) dan menunggu persetujuan (approval).`,
              ],
            );
          } catch (_) {}
        }
      }

      let approvalTargetMsg = 'Admin Aplikasi CATU';
      if (dto.roleCode === 'UMAT') {
        approvalTargetMsg = 'Pengurus Lingkungan';
      } else if (dto.roleCode === 'ROMO_PAROKI') {
        approvalTargetMsg = romoPositionVal === 'KETUA_ROMO' ? 'Admin Aplikasi CATU' : 'Kepala Romo Paroki / Admin Aplikasi CATU';
      } else if (dto.roleCode === 'ROMO_ORDO') {
        approvalTargetMsg = romoPositionVal === 'KETUA_ROMO' ? 'Admin Aplikasi CATU' : 'Ketua Romo Ordo / Admin Aplikasi CATU';
      } else if (dto.roleCode === 'PENGURUS_LINGKUNGAN') {
        approvalTargetMsg = 'Admin Aplikasi CATU';
      }

      return {
        statusCode: 201,
        message: `Registrasi berhasil! Akun Anda sedang menunggu persetujuan dari ${approvalTargetMsg}.`,
        user: {
          id: authUser.id,
          uuid: authUser.uuid,
          fullName: dto.fullName,
          phoneNumber: authUser.phone_number,
          email: dto.email || '',
          roleCode: dto.roleCode,
          accountStatus: authUser.account_status,
          keuskupanId: dto.keuskupanId || null,
          parokiId: dto.parokiId || null,
          wilayahId: dto.wilayahId || null,
          lingkunganId: dto.lingkunganId || null,
          ordoId: dto.ordoId || null,
          keuskupanName: keuskupanName || null,
          parokiName: parokiName || null,
          wilayahName: wilayahName || null,
          lingkunganName: lingkunganName || null,
          ordoName: ordoName || null,
          kabupatenKotaName: 'JAKARTA TIMUR',
          pengurusPosition: dto.pengurusPosition,
          romoPosition: romoPositionVal,
          jabatanStartYear: startYear,
          jabatanEndYear: endYear,
          jabatanStartDate: dto.jabatanStartDate,
          jabatanEndDate: dto.jabatanEndDate,
          isJabatanActive: initialActiveFlag,
        },
        approvalAssignedTo: approverName,
      };
    } catch (err: any) {
      if (queryRunner.isTransactionActive) {
        await queryRunner.rollbackTransaction();
      }
      if (err instanceof BadRequestException || err.status === 400) {
        throw err;
      }
      const errMessage = err.message || '';
      if (err.code === '23505' || errMessage.includes('auth_users_phone_number_key') || errMessage.includes('unique constraint') || errMessage.includes('phone_number')) {
        throw new BadRequestException('Nomor WhatsApp / HP ini sudah terdaftar. Silakan gunakan nomor lain atau login.');
      }
      throw new BadRequestException(errMessage || 'Registrasi gagal. Silakan periksa kembali data Anda.');
    } finally {
      await queryRunner.release();
    }
  }

  @Post('login')
  @HttpCode(200)
  @ApiOperation({
    summary: 'Login User & Ambil Access Token',
    description: 'Login menggunakan nomor HP terdaftar (auth_users JOIN user_profiles). Nomor HP: 6281234567890, Password: password123',
  })
  @ApiResponse({ status: 200, description: 'Login berhasil, mengembalikan token JWT dan profil user lengkap.', type: LoginResponseDto })
  async login(@Body() dto: LoginDto) {
    let phone = dto.phoneNumber.trim();
    if (phone.startsWith('0')) phone = phone.substring(1);
    if (phone.startsWith('62')) phone = phone.substring(2);
    const fullPhone = `62${phone}`;
    const localPhone = `0${phone}`;

    const users = await this.dataSource.query(
      `SELECT u.id, u.uuid, u.phone_number, u.password_hash, u.account_status, r.code as role_code,
              p.full_name, p.email, p.birth_date, p.address, p.avatar_url, p.keuskupan_id, p.paroki_id, p.wilayah_id, p.lingkungan_id, p.ordo_id, p.kabupaten_kota_id, kk.provinsi_id,
              k.name as keuskupan_name, par.name as paroki_name, w.name as wilayah_name, l.name as lingkungan_name, ord.name as ordo_name, kk.name as kota_name,
              p.pengurus_position, p.romo_position, p.jabatan_start_year, p.jabatan_end_year, p.jabatan_start_date, p.jabatan_end_date, p.is_jabatan_active
       FROM auth_users u
       JOIN roles r ON u.role_id = r.id
       JOIN user_profiles p ON p.user_id = u.id
       LEFT JOIN keuskupan k ON p.keuskupan_id = k.id
       LEFT JOIN paroki par ON p.paroki_id = par.id
       LEFT JOIN wilayah w ON p.wilayah_id = w.id
       LEFT JOIN lingkungan l ON p.lingkungan_id = l.id
       LEFT JOIN ordo ord ON p.ordo_id = ord.id
       LEFT JOIN kabupaten_kota kk ON p.kabupaten_kota_id = kk.id
       WHERE u.phone_number = $1 OR u.phone_number = $2`,
      [fullPhone, localPhone],
    );

    if (!users.length) {
      return { statusCode: 401, message: 'Nomor HP atau Password salah' };
    }

    const dbPasswordHash = users[0].password_hash;
    const isPasswordValid = await bcrypt.compare(dto.password, dbPasswordHash);

    if (!isPasswordValid) {
      return { statusCode: 401, message: 'Nomor HP atau Password salah' };
    }

    const user = users[0];

    // Admin tidak boleh login di aplikasi mobile
    if (user.role_code === 'ADMIN') {
      return {
        statusCode: 403,
        message: 'Akun Administrator tidak dapat login melalui aplikasi mobile. Silakan gunakan Web Portal Admin di browser komputer (http://localhost:8000).',
      };
    }

    const accessToken = this.jwtService.sign({
      sub: user.id,
      uuid: user.uuid,
      phoneNumber: user.phone_number,
      roleCode: user.role_code,
      fullName: user.full_name,
    });

    return {
      statusCode: 200,
      message: 'Login Berhasil',
      accessToken,
      user: {
        id: user.id,
        uuid: user.uuid,
        fullName: user.full_name,
        phoneNumber: user.phone_number,
        email: user.email,
        birthDate: user.birth_date,
        address: user.address,
        avatarUrl: user.avatar_url,
        roleCode: user.role_code,
        accountStatus: user.account_status,
        keuskupanId: user.keuskupan_id,
        parokiId: user.paroki_id,
        wilayahId: user.wilayah_id,
        lingkunganId: user.lingkungan_id,
        ordoId: user.ordo_id,
        kabupatenKotaId: user.kabupaten_kota_id,
        provinsiId: user.provinsi_id,
        keuskupanName: user.keuskupan_name,
        parokiName: user.paroki_name,
        wilayahName: user.wilayah_name,
        lingkunganName: user.lingkungan_name,
        ordoName: user.ordo_name,
        kabupatenKotaName: user.kota_name,
        pengurusPosition: user.pengurus_position,
        romoPosition: user.romo_position,
        jabatanStartYear: user.jabatan_start_year,
        jabatanEndYear: user.jabatan_end_year,
        jabatanStartDate: user.jabatan_start_date,
        jabatanEndDate: user.jabatan_end_date,
        isJabatanActive: user.is_jabatan_active !== null ? user.is_jabatan_active : false,
      },
    };
  }

  @Post('admin/login')
  @HttpCode(200)
  @ApiOperation({
    summary: 'Login Khusus Administrator Web Portal',
    description: 'Hanya mengizinkan akun dengan peran ADMIN. User peran lain (UMAT, ROMO, PENGURUS) akan ditolak dengan status 403.',
  })
  async adminLogin(@Body() dto: LoginDto) {
    let phone = dto.phoneNumber.trim();
    if (phone.startsWith('0')) phone = phone.substring(1);
    if (phone.startsWith('62')) phone = phone.substring(2);
    const fullPhone = `62${phone}`;

    const users = await this.dataSource.query(
      `SELECT u.id, u.uuid, u.phone_number, u.password_hash, u.account_status, r.code as role_code,
              p.full_name, p.email, p.birth_date, p.address, p.avatar_url, p.keuskupan_id, p.paroki_id, p.wilayah_id, p.lingkungan_id, p.kabupaten_kota_id, kk.provinsi_id,
              k.name as keuskupan_name, par.name as paroki_name, w.name as wilayah_name, l.name as lingkungan_name, kk.name as kota_name,
              p.pengurus_position, p.romo_position, p.jabatan_start_year, p.jabatan_end_year, p.jabatan_start_date, p.jabatan_end_date, p.is_jabatan_active
       FROM auth_users u
       JOIN roles r ON u.role_id = r.id
       JOIN user_profiles p ON p.user_id = u.id
       LEFT JOIN keuskupan k ON p.keuskupan_id = k.id
       LEFT JOIN paroki par ON p.paroki_id = par.id
       LEFT JOIN wilayah w ON p.wilayah_id = w.id
       LEFT JOIN lingkungan l ON p.lingkungan_id = l.id
       LEFT JOIN kabupaten_kota kk ON p.kabupaten_kota_id = kk.id
       WHERE u.phone_number = $1 OR u.phone_number = $2 OR u.phone_number = $3`,
      [fullPhone, `0${phone}`, dto.phoneNumber.trim()],
    );

    if (!users.length) {
      return { statusCode: 401, message: 'Nomor WhatsApp / HP atau kata sandi salah' };
    }

    const user = users[0];

    // Check Role: MUST BE ADMIN
    if (user.role_code !== 'ADMIN') {
      return {
        statusCode: 403,
        message: `Akses Ditolak: Portal Web ini khusus untuk Administrator Sistem. Pengguna peran "${user.role_code}" silakan masuk melalui Aplikasi Mobile CATU.`,
      };
    }

    const dbPasswordHash = user.password_hash;
    const isPasswordValid = await bcrypt.compare(dto.password, dbPasswordHash);

    if (!isPasswordValid) {
      return { statusCode: 401, message: 'Nomor WhatsApp / HP atau kata sandi salah' };
    }

    const accessToken = this.jwtService.sign({
      sub: user.id,
      uuid: user.uuid,
      phoneNumber: user.phone_number,
      roleCode: user.role_code,
      fullName: user.full_name,
      isAdmin: true,
    });

    return {
      statusCode: 200,
      message: 'Login Administrator Berhasil',
      accessToken,
      user: {
        id: user.id,
        uuid: user.uuid,
        fullName: user.full_name,
        phoneNumber: user.phone_number,
        email: user.email,
        roleCode: user.role_code,
        accountStatus: user.account_status,
      },
    };
  }

  // ── Forgot Password Endpoints ──

  @Post('forgot-password/request-otp')
  @ApiOperation({
    summary: 'Request OTP untuk Lupa Kata Sandi (WhatsApp OTP)',
    description: 'Mengirimkan kode OTP verifikasi 6-digit ke nomor WhatsApp pengguna terdaftar.',
  })
  async requestResetOtp(@Body() dto: RequestResetOtpDto) {
    let phone = dto.phoneNumber.trim();
    if (phone.startsWith('0')) phone = phone.substring(1);
    if (phone.startsWith('62')) phone = phone.substring(2);
    const fullPhone = `62${phone}`;

    const users = await this.dataSource.query(
      `SELECT u.id, u.phone_number, p.full_name
       FROM auth_users u
       LEFT JOIN user_profiles p ON p.user_id = u.id
       WHERE u.phone_number = $1 OR u.phone_number = $2 OR u.phone_number = $3`,
      [fullPhone, `0${phone}`, dto.phoneNumber.trim()],
    );

    if (!users.length) {
      return {
        statusCode: 404,
        message: 'Nomor WhatsApp tidak terdaftar di sistem CATU.',
      };
    }

    const user = users[0];
    const demoOtp = '123456';
    const maskedPhone = fullPhone.replace(/(\d{4})\d+(\d{3})/, '$1-****-$2');

    return {
      statusCode: 200,
      message: 'Kode OTP verifikasi berhasil dikirimkan ke WhatsApp Anda.',
      phoneNumber: user.phone_number,
      fullName: user.full_name || 'Pengguna',
      maskedPhone,
      demoOtp,
    };
  }

  @Post('forgot-password/verify-otp')
  @ApiOperation({
    summary: 'Verifikasi Kode OTP Lupa Kata Sandi',
  })
  async verifyResetOtp(@Body() dto: VerifyResetOtpDto) {
    const otp = dto.otpCode.trim();
    if (!otp || otp.length < 4) {
      return {
        statusCode: 400,
        message: 'Kode OTP tidak valid.',
      };
    }

    if (otp !== '123456' && otp.length !== 6) {
      return {
        statusCode: 400,
        message: 'Kode OTP salah atau telah kadaluarsa.',
      };
    }

    return {
      statusCode: 200,
      message: 'Verifikasi kode OTP berhasil.',
      verified: true,
    };
  }

  @Post('forgot-password/reset')
  @ApiOperation({
    summary: 'Reset / Simpan Kata Sandi Baru',
  })
  async resetPassword(@Body() dto: ResetPasswordDto) {
    let phone = dto.phoneNumber.trim();
    if (phone.startsWith('0')) phone = phone.substring(1);
    if (phone.startsWith('62')) phone = phone.substring(2);
    const fullPhone = `62${phone}`;

    if (!dto.newPassword || dto.newPassword.length < 6) {
      return {
        statusCode: 400,
        message: 'Kata sandi baru minimal 6 karakter.',
      };
    }

    const users = await this.dataSource.query(
      `SELECT id, phone_number FROM auth_users
       WHERE phone_number = $1 OR phone_number = $2 OR phone_number = $3`,
      [fullPhone, `0${phone}`, dto.phoneNumber.trim()],
    );

    if (!users.length) {
      return {
        statusCode: 404,
        message: 'Pengguna tidak ditemukan.',
      };
    }

    const newHash = await bcrypt.hash(dto.newPassword, 10);

    await this.dataSource.query(
      `UPDATE auth_users
       SET password_hash = $1, updated_at = CURRENT_TIMESTAMP
       WHERE id = $2`,
      [newHash, users[0].id],
    );

    return {
      statusCode: 200,
      message: 'Kata sandi berhasil diperbarui! Silakan masuk dengan kata sandi baru Anda.',
    };
  }

  @Get('profile/:userId')
  @ApiBearerAuth('JWT-auth')
  @ApiOperation({ summary: 'Ambil Detail Profil User Lengkap dari Database' })
  async getProfile(@Param('userId') userId: string) {
    const uid = parseInt(userId);
    if (isNaN(uid)) throw new BadRequestException('User ID tidak valid');

    const users = await this.dataSource.query(
      `SELECT u.id, u.uuid, u.phone_number, u.account_status, u.role_id, r.code as role_code,
              p.full_name, p.email, p.birth_date, p.address, p.avatar_url, p.ordo_id, ord.name as ordo_name,
              p.keuskupan_id, p.paroki_id, p.wilayah_id, p.lingkungan_id, p.kabupaten_kota_id,
              p.pengurus_position, p.romo_position, p.jabatan_start_year, p.jabatan_end_year,
              p.jabatan_start_date, p.jabatan_end_date, p.is_jabatan_active,
              k.name as keuskupan_name, par.name as paroki_name, w.name as wilayah_name, l.name as lingkungan_name,
              kk.name as kota_name, prov.name as provinsi_name, prov.id as provinsi_id
       FROM auth_users u
       JOIN user_profiles p ON p.user_id = u.id
       JOIN roles r ON u.role_id = r.id
       LEFT JOIN ordo ord ON p.ordo_id = ord.id
       LEFT JOIN keuskupan k ON p.keuskupan_id = k.id
       LEFT JOIN paroki par ON p.paroki_id = par.id
       LEFT JOIN wilayah w ON p.wilayah_id = w.id
       LEFT JOIN lingkungan l ON p.lingkungan_id = l.id
       LEFT JOIN kabupaten_kota kk ON p.kabupaten_kota_id = kk.id
       LEFT JOIN provinsi prov ON kk.provinsi_id = prov.id
       WHERE u.id = $1`,
      [uid],
    );

    if (!users.length) {
      throw new BadRequestException('User tidak ditemukan');
    }

    const user = users[0];
    return {
      statusCode: 200,
      user: {
        id: user.id,
        uuid: user.uuid,
        fullName: user.full_name,
        phoneNumber: user.phone_number,
        email: user.email || '',
        birthDate: user.birth_date || '',
        address: user.address || '',
        avatarUrl: user.avatar_url || '',
        roleCode: user.role_code,
        accountStatus: user.account_status,
        ordoId: user.ordo_id,
        ordoName: user.ordo_name || '',
        keuskupanId: user.role_code === 'ROMO_ORDO' ? null : user.keuskupan_id,
        parokiId: user.role_code === 'ROMO_ORDO' ? null : user.paroki_id,
        wilayahId: user.role_code === 'ROMO_ORDO' ? null : user.wilayah_id,
        lingkunganId: user.role_code === 'ROMO_ORDO' ? null : user.lingkungan_id,
        kabupatenKotaId: user.kabupaten_kota_id,
        provinsiId: user.provinsi_id,
        keuskupanName: user.role_code === 'ROMO_ORDO' ? '' : (user.keuskupan_name || ''),
        parokiName: user.role_code === 'ROMO_ORDO' ? '' : (user.paroki_name || ''),
        wilayahName: user.role_code === 'ROMO_ORDO' ? '' : (user.wilayah_name || ''),
        lingkunganName: user.role_code === 'ROMO_ORDO' ? '' : (user.lingkungan_name || ''),
        kabupatenKotaName: user.kota_name || '',
        provinsiName: user.provinsi_name || '',
        pengurusPosition: user.pengurus_position,
        romoPosition: user.romo_position,
        jabatanStartYear: user.jabatan_start_year,
        jabatanEndYear: user.jabatan_end_year,
        jabatanStartDate: user.jabatan_start_date,
        jabatanEndDate: user.jabatan_end_date,
        isJabatanActive: user.is_jabatan_active !== null ? user.is_jabatan_active : false,
      },
    };
  }

  @Put('profile/:userId')
  @ApiBearerAuth('JWT-auth')
  @ApiOperation({ summary: 'Ubah Data Profil User & Domisili Keumatan' })
  async updateProfile(
    @Param('userId') userId: string,
    @Body() dto: UpdateUserProfileDto,
  ) {
    const uid = parseInt(userId);
    if (isNaN(uid)) throw new BadRequestException('User ID tidak valid');

    if (dto.phoneNumber) {
      let cleanPhone = dto.phoneNumber.trim().replace(/\D/g, '');
      if (!cleanPhone.startsWith('62')) {
        if (cleanPhone.startsWith('0')) cleanPhone = '62' + cleanPhone.substring(1);
        else cleanPhone = '62' + cleanPhone;
      }

      // Check if phone number is already used by another user
      const existingPhone = await this.dataSource.query(
        `SELECT id, phone_number FROM auth_users WHERE (phone_number = $1 OR phone_number = $2 OR phone_number = $3) AND id != $4`,
        [cleanPhone, cleanPhone.replace(/^62/, '0'), cleanPhone.replace(/^62/, ''), uid],
      );
      if (existingPhone.length > 0) {
        throw new BadRequestException('Nomor WhatsApp ini sudah terdaftar dan digunakan oleh pengguna lain!');
      }

      await this.dataSource.query(
        `UPDATE auth_users SET phone_number = $1 WHERE id = $2`,
        [cleanPhone, uid],
      );
    }

    if (dto.roleCode || (dto as any).role_code) {
      const targetRole = dto.roleCode || (dto as any).role_code;
      const roleRes = await this.dataSource.query(`SELECT id FROM roles WHERE code = $1`, [targetRole]);
      if (roleRes.length > 0) {
        await this.dataSource.query(`UPDATE auth_users SET role_id = $1 WHERE id = $2`, [roleRes[0].id, uid]);
      }
    }

    const userRoleRes = await this.dataSource.query(
      `SELECT r.code FROM auth_users u JOIN roles r ON u.role_id = r.id WHERE u.id = $1`,
      [uid],
    );
    const activeRoleCode = dto.roleCode || (userRoleRes[0] ? userRoleRes[0].code : '');

    const targetLingkunganId = (dto.lingkunganId !== undefined || (dto as any).lingkungan_id !== undefined)
      ? (dto.lingkunganId ?? (dto as any).lingkungan_id)
      : null;
    const targetPengurusPos = (dto as any).pengurusPosition ?? (dto as any).pengurus_position;

    if (activeRoleCode === 'PENGURUS_LINGKUNGAN' || targetPengurusPos) {
      let checkLingkunganId = targetLingkunganId;
      if (!checkLingkunganId) {
        const curProf = await this.dataSource.query(`SELECT lingkungan_id FROM user_profiles WHERE user_id = $1`, [uid]);
        checkLingkunganId = curProf[0]?.lingkungan_id;
      }
      let checkPos = targetPengurusPos;
      if (!checkPos) {
        const curProf = await this.dataSource.query(`SELECT pengurus_position FROM user_profiles WHERE user_id = $1`, [uid]);
        checkPos = curProf[0]?.pengurus_position;
      }

      if (checkLingkunganId && checkPos) {
        const existingPengurus = await this.dataSource.query(
          `SELECT u.id, p.full_name, p.pengurus_position
           FROM user_profiles p
           JOIN auth_users u ON p.user_id = u.id
           WHERE p.lingkungan_id = $1
             AND u.id != $2
             AND u.account_status IN ('APPROVED', 'PENDING_APPROVAL')
             AND (
               LOWER(p.pengurus_position) = LOWER($3)
               OR (LOWER($3) LIKE '%ketua%' AND LOWER($3) NOT LIKE '%wakil%' AND LOWER(p.pengurus_position) LIKE '%ketua%' AND LOWER(p.pengurus_position) NOT LIKE '%wakil%')
               OR (LOWER($3) LIKE '%wakil%' AND LOWER(p.pengurus_position) LIKE '%wakil%')
               OR (LOWER($3) LIKE '%sekretaris%' AND LOWER(p.pengurus_position) LIKE '%sekretaris%')
               OR (LOWER($3) LIKE '%bendahara%' AND LOWER(p.pengurus_position) LIKE '%bendahara%')
             )`,
          [checkLingkunganId, uid, checkPos],
        );
        if (existingPengurus.length > 0) {
          const existingName = existingPengurus[0].full_name;
          const existingPos = existingPengurus[0].pengurus_position;
          throw new BadRequestException(
            `Jabatan ${checkPos} untuk lingkungan ini sudah terisi oleh ${existingName} (${existingPos}). Pengurus dengan jabatan yang sama tidak boleh ganda dalam satu lingkungan.`,
          );
        }
      }
    }

    const fields: string[] = [];
    const values: any[] = [];
    let idx = 1;

    if (dto.fullName !== undefined) {
      fields.push(`full_name = $${idx++}`);
      values.push(dto.fullName);
    }
    if (dto.email !== undefined) {
      fields.push(`email = $${idx++}`);
      values.push(dto.email);
    }
    if (dto.birthDate !== undefined) {
      const bDate = dto.birthDate && String(dto.birthDate).trim() ? String(dto.birthDate).trim() : null;
      fields.push(`birth_date = $${idx++}`);
      values.push(bDate);
    }
    if (dto.address !== undefined) {
      fields.push(`address = $${idx++}`);
      values.push(dto.address);
    }
    if (dto.avatarUrl !== undefined) {
      fields.push(`avatar_url = $${idx++}`);
      values.push(dto.avatarUrl);
    }
    if (activeRoleCode === 'ROMO_ORDO') {
      fields.push(`keuskupan_id = NULL`, `paroki_id = NULL`, `wilayah_id = NULL`, `lingkungan_id = NULL`);
    } else {
      if (dto.keuskupanId !== undefined || (dto as any).keuskupan_id !== undefined) {
        const kId = (dto.keuskupanId ?? (dto as any).keuskupan_id) ? parseInt(dto.keuskupanId ?? (dto as any).keuskupan_id) : null;
        fields.push(`keuskupan_id = $${idx++}`);
        values.push(kId && !isNaN(kId) && kId > 0 ? kId : null);
      }
      if (dto.parokiId !== undefined || (dto as any).paroki_id !== undefined) {
        const pId = (dto.parokiId ?? (dto as any).paroki_id) ? parseInt(dto.parokiId ?? (dto as any).paroki_id) : null;
        fields.push(`paroki_id = $${idx++}`);
        values.push(pId && !isNaN(pId) && pId > 0 ? pId : null);
      }
      if (dto.wilayahId !== undefined || (dto as any).wilayah_id !== undefined) {
        const wId = (dto.wilayahId ?? (dto as any).wilayah_id) ? parseInt(dto.wilayahId ?? (dto as any).wilayah_id) : null;
        fields.push(`wilayah_id = $${idx++}`);
        values.push(wId && !isNaN(wId) && wId > 0 ? wId : null);
      }
      if (dto.lingkunganId !== undefined || (dto as any).lingkungan_id !== undefined) {
        const lId = (dto.lingkunganId ?? (dto as any).lingkungan_id) ? parseInt(dto.lingkunganId ?? (dto as any).lingkungan_id) : null;
        fields.push(`lingkungan_id = $${idx++}`);
        values.push(lId && !isNaN(lId) && lId > 0 ? lId : null);
      }
    }
    if (dto.kabupatenKotaId !== undefined || (dto as any).kabupaten_kota_id !== undefined) {
      const kkId = (dto.kabupatenKotaId ?? (dto as any).kabupaten_kota_id) ? parseInt(dto.kabupatenKotaId ?? (dto as any).kabupaten_kota_id) : null;
      fields.push(`kabupaten_kota_id = $${idx++}`);
      values.push(kkId && !isNaN(kkId) && kkId > 0 ? kkId : null);
    }
    if (dto.ordoId !== undefined || (dto as any).ordo_id !== undefined) {
      const oId = (dto.ordoId ?? (dto as any).ordo_id) ? parseInt(dto.ordoId ?? (dto as any).ordo_id) : null;
      fields.push(`ordo_id = $${idx++}`);
      values.push(oId && !isNaN(oId) && oId > 0 ? oId : null);
    }
    if ((dto as any).pengurusPosition !== undefined || (dto as any).pengurus_position !== undefined) {
      fields.push(`pengurus_position = $${idx++}`);
      values.push((dto as any).pengurusPosition ?? (dto as any).pengurus_position);
    }
    if ((dto as any).romoPosition !== undefined || (dto as any).romo_position !== undefined) {
      fields.push(`romo_position = $${idx++}`);
      values.push((dto as any).romoPosition ?? (dto as any).romo_position);
    }
    if ((dto as any).jabatanStartYear !== undefined || (dto as any).jabatan_start_year !== undefined) {
      fields.push(`jabatan_start_year = $${idx++}`);
      values.push((dto as any).jabatanStartYear ?? (dto as any).jabatan_start_year);
    }
    if ((dto as any).jabatanEndYear !== undefined || (dto as any).jabatan_end_year !== undefined) {
      fields.push(`jabatan_end_year = $${idx++}`);
      values.push((dto as any).jabatanEndYear ?? (dto as any).jabatan_end_year);
    }
    if ((dto as any).isJabatanActive !== undefined || (dto as any).is_jabatan_active !== undefined) {
      fields.push(`is_jabatan_active = $${idx++}`);
      values.push((dto as any).isJabatanActive ?? (dto as any).is_jabatan_active);
    }

    if ((dto as any).accountStatus !== undefined || (dto as any).account_status !== undefined) {
      const targetStatus = (dto as any).accountStatus ?? (dto as any).account_status;
      await this.dataSource.query(`UPDATE auth_users SET account_status = $1 WHERE id = $2`, [targetStatus, uid]);
    }

    if (fields.length > 0) {
      fields.push(`updated_at = NOW()`);
      values.push(uid);
      await this.dataSource.query(
        `UPDATE user_profiles SET ${fields.join(', ')} WHERE user_id = $${idx}`,
        values,
      );
    }

    const updated = await this.dataSource.query(
      `SELECT u.id, u.uuid, u.phone_number, u.account_status, u.role_id, r.code as role_code,
              p.full_name, p.email, p.birth_date, p.address, p.avatar_url, p.ordo_id, ord.name as ordo_name,
              p.keuskupan_id, p.paroki_id, p.wilayah_id, p.lingkungan_id, p.kabupaten_kota_id,
              p.pengurus_position, p.romo_position, p.jabatan_start_year, p.jabatan_end_year,
              p.jabatan_start_date, p.jabatan_end_date, p.is_jabatan_active,
              k.name as keuskupan_name, par.name as paroki_name, w.name as wilayah_name, l.name as lingkungan_name,
              kk.name as kota_name, prov.name as provinsi_name, prov.id as provinsi_id
       FROM auth_users u
       JOIN user_profiles p ON p.user_id = u.id
       JOIN roles r ON u.role_id = r.id
       LEFT JOIN ordo ord ON p.ordo_id = ord.id
       LEFT JOIN keuskupan k ON p.keuskupan_id = k.id
       LEFT JOIN paroki par ON p.paroki_id = par.id
       LEFT JOIN wilayah w ON p.wilayah_id = w.id
       LEFT JOIN lingkungan l ON p.lingkungan_id = l.id
       LEFT JOIN kabupaten_kota kk ON p.kabupaten_kota_id = kk.id
       LEFT JOIN provinsi prov ON kk.provinsi_id = prov.id
       WHERE u.id = $1`,
      [uid],
    );

    const uObj = updated[0] ? {
      id: updated[0].id,
      uuid: updated[0].uuid,
      fullName: updated[0].full_name,
      phoneNumber: updated[0].phone_number,
      email: updated[0].email || '',
      birthDate: updated[0].birth_date || '',
      address: updated[0].address || '',
      avatarUrl: updated[0].avatar_url || '',
      roleCode: updated[0].role_code,
      accountStatus: updated[0].account_status,
      ordoId: updated[0].ordo_id,
      ordoName: updated[0].ordo_name || '',
      keuskupanId: updated[0].keuskupan_id,
      parokiId: updated[0].paroki_id,
      wilayahId: updated[0].wilayah_id,
      lingkunganId: updated[0].lingkungan_id,
      kabupatenKotaId: updated[0].kabupaten_kota_id,
      provinsiId: updated[0].provinsi_id,
      keuskupanName: updated[0].keuskupan_name || '',
      parokiName: updated[0].paroki_name || '',
      wilayahName: updated[0].wilayah_name || '',
      lingkunganName: updated[0].lingkungan_name || '',
      kabupatenKotaName: updated[0].kota_name || '',
      provinsiName: updated[0].provinsi_name || '',
    } : {};

    return {
      statusCode: 200,
      message: 'Profil pengguna berhasil diperbarui!',
      user: uObj,
    };
  }

  @Post('approve-registration')
  @ApiBearerAuth('JWT-auth')
  @ApiOperation({
    summary: 'Persetujuan Registrasi Pendaftaran User (Approval di auth_users)',
    description: 'Mengubah status pendaftaran user di auth_users dari PENDING_APPROVAL menjadi APPROVED atau REJECTED.',
  })
  @ApiResponse({ status: 200, description: 'Status persetujuan akun berhasil diperbarui.', type: ApproveUserResponseDto })
  async approveRegistration(@Body() dto: ApproveUserDto) {
    if (dto.action === 'APPROVED') {
      const targetProf = await this.dataSource.query(
        `SELECT u.role_id, r.code as role_code, p.lingkungan_id, p.keuskupan_id, p.pengurus_position, p.full_name
         FROM auth_users u
         JOIN roles r ON u.role_id = r.id
         LEFT JOIN user_profiles p ON u.id = p.user_id
         WHERE u.id = $1`,
        [dto.targetUserId],
      );

      if (targetProf.length > 0) {
        const roleCode = targetProf[0].role_code;
        const pengurusPos = (targetProf[0].pengurus_position || '').toString().toLowerCase();
        const isKoordinator = pengurusPos.includes('koordinator') || roleCode === 'KOORDINATOR';

        // Check if Koordinator in that Keuskupan already exists
        if (isKoordinator && targetProf[0].keuskupan_id) {
          const existingKoordinator = await this.dataSource.query(
            `SELECT u.id, p.full_name, p.pengurus_position
             FROM user_profiles p
             JOIN auth_users u ON p.user_id = u.id
             WHERE p.keuskupan_id = $1
               AND u.id != $2
               AND u.account_status = 'APPROVED'
               AND LOWER(p.pengurus_position) LIKE '%koordinator%'`,
            [targetProf[0].keuskupan_id, dto.targetUserId],
          );
          if (existingKoordinator.length > 0) {
            throw new BadRequestException(
              `Gagal menyetujui akun: Jabatan Koordinator untuk keuskupan ini sudah aktif oleh ${existingKoordinator[0].full_name}.`,
            );
          }
        }

        // Pengurus Lingkungan duplicate position check
        if (roleCode === 'PENGURUS_LINGKUNGAN' && targetProf[0].lingkungan_id && targetProf[0].pengurus_position) {
          const existingApproved = await this.dataSource.query(
            `SELECT u.id, p.full_name, p.pengurus_position
             FROM user_profiles p
             JOIN auth_users u ON p.user_id = u.id
             WHERE p.lingkungan_id = $1
               AND u.id != $2
               AND u.account_status = 'APPROVED'
               AND (
                 LOWER(p.pengurus_position) = LOWER($3)
                 OR (LOWER($3) LIKE '%ketua%' AND LOWER($3) NOT LIKE '%wakil%' AND LOWER(p.pengurus_position) LIKE '%ketua%' AND LOWER(p.pengurus_position) NOT LIKE '%wakil%')
                 OR (LOWER($3) LIKE '%wakil%' AND LOWER(p.pengurus_position) LIKE '%wakil%')
                 OR (LOWER($3) LIKE '%sekretaris%' AND LOWER(p.pengurus_position) LIKE '%sekretaris%')
                 OR (LOWER($3) LIKE '%bendahara%' AND LOWER(p.pengurus_position) LIKE '%bendahara%')
               )`,
            [targetProf[0].lingkungan_id, dto.targetUserId, targetProf[0].pengurus_position],
          );
          if (existingApproved.length > 0) {
            throw new BadRequestException(
              `Gagal menyetujui akun: Jabatan ${targetProf[0].pengurus_position} pada lingkungan ini sudah terisi dan aktif oleh ${existingApproved[0].full_name}. Tidak boleh ada jabatan pengurus yang ganda dalam satu lingkungan.`,
            );
          }
        }
      }

      await this.dataSource.query(
        `UPDATE user_profiles SET is_jabatan_active = TRUE WHERE user_id = $1`,
        [dto.targetUserId],
      );
    }

    const updated = await this.dataSource.query(
      `UPDATE auth_users SET account_status = $1 WHERE id = $2 RETURNING id, account_status`,
      [dto.action, dto.targetUserId],
    );

    const userProfile = await this.dataSource.query(`SELECT full_name FROM user_profiles WHERE user_id = $1`, [dto.targetUserId]);

    // Audit Log Approval
    await this.dataSource.query(
      `INSERT INTO user_approvals (target_user_id, approver_user_id, action, rejection_reason) VALUES ($1, 7, $2, $3)`,
      [dto.targetUserId, dto.action, dto.rejectionReason || null],
    );

    return {
      statusCode: 200,
      message: `Akun user ${userProfile[0]?.full_name || ''} (ID: ${dto.targetUserId}) telah berhasil di-${dto.action}`,
      targetUserId: dto.targetUserId,
      status: dto.action,
      approvedBy: 'Super Admin CATU / Ketua Lingkungan',
      approvedAt: new Date().toISOString(),
    };
  }

  // ── Admin Dashboard Endpoints ──

  @Get('admin/analytics')
  @ApiBearerAuth('JWT-auth')
  @ApiOperation({ summary: 'Ringkasan Metrik Dashboard Admin CATU' })
  async getAdminAnalytics() {
    const totalOrdersRes = await this.dataSource.query(`
      SELECT
        COUNT(*) as total,
        COUNT(*) FILTER (WHERE status::text = 'PENDING') as pending,
        COUNT(*) FILTER (WHERE status::text = 'CONFIRMED' OR status::text = 'ACCEPTED' OR status::text = 'IN_PROGRESS') as confirmed,
        COUNT(*) FILTER (WHERE status::text = 'DONE' OR status::text = 'SELESAI' OR status::text = 'COMPLETED') as done,
        COUNT(*) FILTER (WHERE status::text = 'FAIL' OR status::text = 'REJECTED' OR status::text = 'CANCELLED') as fail
      FROM orders
    `);

    const categoriesRes = await this.dataSource.query(`
      SELECT sc.name, COUNT(o.id) as count
      FROM service_categories sc
      LEFT JOIN orders o ON o.service_category_id = sc.id
      GROUP BY sc.name
    `);

    const usersRes = await this.dataSource.query(`
      SELECT
        COUNT(*) as total,
        COUNT(*) FILTER (WHERE u.account_status = 'PENDING_APPROVAL') as pending_approvals,
        COUNT(*) FILTER (WHERE u.account_status = 'PENDING_APPROVAL' AND (LOWER(p.pengurus_position) LIKE '%koordinator%' OR r.code = 'KOORDINATOR')) as pending_koordinator,
        COUNT(*) FILTER (WHERE r.code = 'UMAT' AND (p.pengurus_position IS NULL OR LOWER(p.pengurus_position) NOT LIKE '%koordinator%')) as total_umat,
        COUNT(*) FILTER (WHERE LOWER(p.pengurus_position) LIKE '%koordinator%' OR r.code = 'KOORDINATOR') as total_koordinator,
        COUNT(*) FILTER (WHERE r.code = 'ROMO_PAROKI') as total_romo_paroki,
        COUNT(*) FILTER (WHERE r.code = 'ROMO_ORDO') as total_romo_ordo,
        COUNT(*) FILTER (WHERE r.code = 'PENGURUS_LINGKUNGAN' OR (p.pengurus_position IS NOT NULL AND LOWER(p.pengurus_position) NOT LIKE '%koordinator%')) as total_pengurus,
        COUNT(*) FILTER (WHERE r.code = 'ADMIN') as total_admin
      FROM auth_users u
      JOIN roles r ON u.role_id = r.id
      LEFT JOIN user_profiles p ON p.user_id = u.id
    `);

    const recentOrders = await this.dataSource.query(`
      SELECT o.id, o.order_number, sc.name as category_name, o.status, p.full_name as pemohon_name, o.created_at
      FROM orders o
      JOIN service_categories sc ON o.service_category_id = sc.id
      JOIN user_profiles p ON o.user_id = p.user_id
      ORDER BY o.id DESC LIMIT 5
    `);

    const recentUsers = await this.dataSource.query(`
      SELECT u.id, u.phone_number, r.code as role_code, r.name as role_name, p.full_name, u.account_status, u.created_at, p.pengurus_position
      FROM auth_users u
      JOIN roles r ON u.role_id = r.id
      LEFT JOIN user_profiles p ON p.user_id = u.id
      ORDER BY u.id DESC LIMIT 5
    `);

    return {
      statusCode: 200,
      orders: totalOrdersRes[0] || {},
      users: usersRes[0] || {},
      categories: categoriesRes || [],
      recentOrders: recentOrders || [],
      recentUsers: recentUsers || [],
    };
  }

  @Get('admin/users')
  @ApiBearerAuth('JWT-auth')
  @ApiOperation({ summary: 'Daftar Semua Pengguna untuk Manajemen Admin' })
  async getAdminUsers(
    @Query('role') role?: string,
    @Query('status') status?: string,
    @Query('search') search?: string,
  ) {
    let query = `
      SELECT u.id, u.uuid, u.phone_number, u.account_status, u.is_active, u.created_at,
             r.id as role_id, r.code as role_code, r.name as role_name,
             p.full_name, p.email, p.birth_date, p.address, p.avatar_url,
             p.keuskupan_id, k.name as keuskupan_name,
             p.paroki_id, par.name as paroki_name,
             p.wilayah_id, w.name as wilayah_name,
             p.lingkungan_id, l.name as lingkungan_name,
             p.kabupaten_kota_id, kk.name as kota_name, kk.provinsi_id, prov.name as provinsi_name,
             p.ordo_id, ord.name as ordo_name,
             p.pengurus_position, p.romo_position,
             p.jabatan_start_year, p.jabatan_end_year, p.jabatan_start_date, p.jabatan_end_date, p.is_jabatan_active
      FROM auth_users u
      JOIN roles r ON u.role_id = r.id
      LEFT JOIN user_profiles p ON p.user_id = u.id
      LEFT JOIN keuskupan k ON p.keuskupan_id = k.id
      LEFT JOIN paroki par ON p.paroki_id = par.id
      LEFT JOIN wilayah w ON p.wilayah_id = w.id
      LEFT JOIN lingkungan l ON p.lingkungan_id = l.id
      LEFT JOIN kabupaten_kota kk ON p.kabupaten_kota_id = kk.id
      LEFT JOIN provinsi prov ON kk.provinsi_id = prov.id
      LEFT JOIN ordo ord ON p.ordo_id = ord.id
    `;

    const whereClauses: string[] = [];
    const params: any[] = [];
    let pIdx = 1;

    if (role && role !== 'ALL') {
      if (role === 'KOORDINATOR') {
        whereClauses.push(`(LOWER(p.pengurus_position) LIKE '%koordinator%' OR r.code = 'KOORDINATOR')`);
      } else if (role === 'UMAT') {
        whereClauses.push(`(r.code = 'UMAT' AND (p.pengurus_position IS NULL OR LOWER(p.pengurus_position) NOT LIKE '%koordinator%'))`);
      } else {
        whereClauses.push(`r.code = $${pIdx++}`);
        params.push(role);
      }
    }
    if (status && status !== 'ALL') {
      whereClauses.push(`u.account_status = $${pIdx++}`);
      params.push(status);
    }
    if (search && search.trim().length > 0) {
      whereClauses.push(`(p.full_name ILIKE $${pIdx} OR u.phone_number ILIKE $${pIdx} OR par.name ILIKE $${pIdx} OR k.name ILIKE $${pIdx})`);
      params.push(`%${search.trim()}%`);
      pIdx++;
    }

    if (whereClauses.length > 0) {
      query += ` WHERE ${whereClauses.join(' AND ')}`;
    }
    query += ` ORDER BY u.id DESC`;

    const users = await this.dataSource.query(query, params);
    return {
      statusCode: 200,
      total: users.length,
      users,
    };
  }

  @Put('admin/users/:userId/status')
  @ApiBearerAuth('JWT-auth')
  @ApiOperation({ summary: 'Update Status Akun Pengguna oleh Admin' })
  async updateAdminUserStatus(
    @Param('userId') userId: string,
    @Body() body: { status: string; isJabatanActive?: boolean },
  ) {
    const uid = parseInt(userId);
    await this.dataSource.query(
      `UPDATE auth_users SET account_status = $1, updated_at = CURRENT_TIMESTAMP WHERE id = $2`,
      [body.status, uid],
    );
    if (body.isJabatanActive !== undefined) {
      await this.dataSource.query(
        `UPDATE user_profiles SET is_jabatan_active = $1 WHERE user_id = $2`,
        [body.isJabatanActive, uid],
      );
    } else if (body.status === 'APPROVED') {
      await this.dataSource.query(
        `UPDATE user_profiles SET is_jabatan_active = true WHERE user_id = $1 AND (pengurus_position IS NOT NULL OR romo_position = 'KETUA_ROMO')`,
        [uid],
      );
    } else if (body.status === 'REJECTED') {
      await this.dataSource.query(
        `UPDATE user_profiles SET is_jabatan_active = false WHERE user_id = $1 AND (pengurus_position IS NOT NULL OR romo_position = 'KETUA_ROMO')`,
        [uid],
      );
    }
    return { statusCode: 200, message: `Status akun user ID ${uid} berhasil diubah menjadi ${body.status}` };
  }

  @Put('admin/users/:userId/role')
  @ApiBearerAuth('JWT-auth')
  @ApiOperation({ summary: 'Update Role Pengguna oleh Admin' })
  async updateAdminUserRole(
    @Param('userId') userId: string,
    @Body() body: { roleCode: string },
  ) {
    const uid = parseInt(userId);
    const roleRes = await this.dataSource.query(`SELECT id FROM roles WHERE code = $1`, [body.roleCode]);
    if (!roleRes.length) throw new BadRequestException('Role tidak valid');
    await this.dataSource.query(
      `UPDATE auth_users SET role_id = $1, updated_at = CURRENT_TIMESTAMP WHERE id = $2`,
      [roleRes[0].id, uid],
    );
    return { statusCode: 200, message: `Role user ID ${uid} berhasil diubah menjadi ${body.roleCode}` };
  }

  @Put('admin/orders/:orderId/status')
  @ApiBearerAuth('JWT-auth')
  @ApiOperation({ summary: 'Update Status Pelayanan oleh Admin' })
  async updateAdminOrderStatus(
    @Param('orderId') orderId: string,
    @Body() body: { status: string },
  ) {
    const oid = parseInt(orderId);
    await this.dataSource.query(
      `UPDATE orders SET status = $1, updated_at = CURRENT_TIMESTAMP WHERE id = $2`,
      [body.status, oid],
    );
    return { statusCode: 200, message: `Status order #${oid} berhasil diubah menjadi ${body.status}` };
  }
}
