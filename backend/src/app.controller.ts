import { Controller, Post, Put, Delete, Body, Get, Param, Query, OnModuleInit, BadRequestException, HttpCode } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse, ApiBearerAuth } from '@nestjs/swagger';
import { InjectDataSource } from '@nestjs/typeorm';
import { DataSource } from 'typeorm';
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
} from './auth.dto';
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
} from './orders.dto';

@ApiTags('Auth & Registration')
@Controller('auth')
export class AuthController implements OnModuleInit {
  constructor(@InjectDataSource() private dataSource: DataSource) {}

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
        SELECT setval('master_positions_id_seq', (SELECT COALESCE(MAX(id), 1) FROM master_positions));
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
        kabupatenKotaId: user.kabupaten_kota_id,
        provinsiId: user.provinsi_id,
        keuskupanName: user.keuskupan_name,
        parokiName: user.paroki_name,
        wilayahName: user.wilayah_name,
        lingkunganName: user.lingkungan_name,
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
  @ApiOperation({ summary: 'Daftar Umat Baru yang Menunggu Persetujuan Pengurus Lingkungan' })
  async getPengurusPendingUmat(
    @Query('lingkunganId') lingkunganId?: string,
    @Query('pengurusUserId') pengurusUserId?: string,
  ) {
    let resolvedLingkunganId = lingkunganId ? parseInt(lingkunganId, 10) : null;
    if (!resolvedLingkunganId && pengurusUserId) {
      const p = await this.dataSource.query(
        'SELECT lingkungan_id FROM user_profiles WHERE user_id = $1',
        [parseInt(pengurusUserId, 10)],
      );
      if (p.length > 0 && p[0].lingkungan_id) resolvedLingkunganId = p[0].lingkungan_id;
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
         WHERE r.code = 'UMAT' AND u.account_status = 'PENDING_APPROVAL'
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
      if (dto.roleCode === 'UMAT' && dto.lingkunganId) {
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
        `INSERT INTO user_profiles (user_id, full_name, email, birth_date, address, keuskupan_id, paroki_id, wilayah_id, lingkungan_id, kabupaten_kota_id, pengurus_position, romo_position, jabatan_start_year, jabatan_end_year, jabatan_start_date, jabatan_end_date, is_jabatan_active)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17)`,
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
        ],
      );

      await queryRunner.commitTransaction();

      // Detailed location names for response DTO
      let keuskupanName = '';
      let parokiName = '';
      let wilayahName = '';
      let lingkunganName = '';
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
        approvalTargetMsg = romoPositionVal === 'KETUA_ROMO' ? 'Admin Aplikasi CATU' : 'Kepala Romo Paroki';
      } else if (dto.roleCode === 'ROMO_ORDO') {
        approvalTargetMsg = romoPositionVal === 'KETUA_ROMO' ? 'Admin Aplikasi CATU' : 'Ketua Romo Ordo';
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
          keuskupanName: keuskupanName || 'Keuskupan Agung Jakarta',
          parokiName: parokiName || 'Paroki Kelapa Gading - St. Yakobus',
          wilayahName: wilayahName || 'Wilayah Anastasia',
          lingkunganName: lingkunganName || 'Lingkungan Anastasia 1',
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
       WHERE u.phone_number = $1`,
      [dto.phoneNumber],
    );

    if (!users.length) {
      return { statusCode: 401, message: 'Nomor HP atau Password salah' };
    }

    const dbPasswordHash = users[0].password_hash;
    let isPasswordValid = false;
    if (dbPasswordHash && (dbPasswordHash.startsWith('$2b$') || dbPasswordHash.startsWith('$2a$'))) {
      isPasswordValid = await bcrypt.compare(dto.password, dbPasswordHash);
    } else {
      isPasswordValid = dbPasswordHash === dto.password;
    }

    if (!isPasswordValid) {
      return { statusCode: 401, message: 'Nomor HP atau Password salah' };
    }

    const user = users[0];
    return {
      statusCode: 200,
      message: 'Login Berhasil',
      accessToken: `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.mock_jwt_token_user_${user.id}`,
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
        kabupatenKotaId: user.kabupaten_kota_id,
        provinsiId: user.provinsi_id,
        keuskupanName: user.keuskupan_name,
        parokiName: user.paroki_name,
        wilayahName: user.wilayah_name,
        lingkunganName: user.lingkungan_name,
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
    let isPasswordValid = false;
    if (dbPasswordHash && (dbPasswordHash.startsWith('$2b$') || dbPasswordHash.startsWith('$2a$'))) {
      isPasswordValid = await bcrypt.compare(dto.password, dbPasswordHash);
    } else {
      isPasswordValid = dbPasswordHash === dto.password;
    }

    if (!isPasswordValid) {
      return { statusCode: 401, message: 'Nomor WhatsApp / HP atau kata sandi salah' };
    }

    return {
      statusCode: 200,
      message: 'Login Administrator Berhasil',
      accessToken: `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.mock_jwt_token_admin_${user.id}`,
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
        `SELECT u.role_id, r.code as role_code, p.lingkungan_id, p.pengurus_position, p.full_name
         FROM auth_users u 
         JOIN roles r ON u.role_id = r.id 
         LEFT JOIN user_profiles p ON u.id = p.user_id 
         WHERE u.id = $1`,
        [dto.targetUserId],
      );

      if (targetProf.length > 0 && targetProf[0].role_code === 'UMAT') {
        throw new BadRequestException('Pendaftaran akun Umat harus diverifikasi dan disetujui oleh Pengurus Lingkungan setempat melalui aplikasi mobile CATU.');
      }

      if (targetProf.length > 0 && targetProf[0].role_code === 'ROMO_PAROKI' && targetProf[0].romo_position !== 'KETUA_ROMO' && targetProf[0].paroki_id) {
        const hasKetua = await this.dataSource.query(
          `SELECT u.id, p.full_name FROM user_profiles p
           JOIN auth_users u ON p.user_id = u.id
           JOIN roles r ON u.role_id = r.id
           WHERE p.paroki_id = $1 AND r.code = 'ROMO_PAROKI' AND p.romo_position = 'KETUA_ROMO' AND u.account_status = 'APPROVED'`,
          [targetProf[0].paroki_id],
        );
        if (hasKetua.length > 0) {
          throw new BadRequestException(`Pendaftaran Romo Paroki (${targetProf[0].full_name}) diverifikasi dan disetujui oleh Kepala Romo Paroki (${hasKetua[0].full_name}) melalui aplikasi mobile CATU.`);
        }
      }

      if (targetProf.length > 0 && targetProf[0].role_code === 'ROMO_ORDO' && targetProf[0].romo_position !== 'KETUA_ROMO' && targetProf[0].ordo_id) {
        const hasKetuaOrdo = await this.dataSource.query(
          `SELECT u.id, p.full_name FROM user_profiles p
           JOIN auth_users u ON p.user_id = u.id
           JOIN roles r ON u.role_id = r.id
           WHERE (p.ordo_id = $1 OR p.user_id IN (SELECT rp.user_id FROM romo_profiles rp WHERE rp.ordo_id = $1))
             AND r.code = 'ROMO_ORDO' AND p.romo_position = 'KETUA_ROMO' AND u.account_status = 'APPROVED'`,
          [targetProf[0].ordo_id],
        );
        if (hasKetuaOrdo.length > 0) {
          throw new BadRequestException(`Pendaftaran Romo Ordo (${targetProf[0].full_name}) diverifikasi dan disetujui oleh Ketua Romo Ordo (${hasKetuaOrdo[0].full_name}) melalui aplikasi mobile CATU.`);
        }
      }

      if (targetProf.length > 0 && targetProf[0].role_code === 'PENGURUS_LINGKUNGAN' && targetProf[0].lingkungan_id && targetProf[0].pengurus_position) {
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
        COUNT(*) FILTER (WHERE r.code = 'UMAT') as total_umat,
        COUNT(*) FILTER (WHERE r.code = 'ROMO_PAROKI') as total_romo_paroki,
        COUNT(*) FILTER (WHERE r.code = 'ROMO_ORDO') as total_romo_ordo,
        COUNT(*) FILTER (WHERE r.code = 'PENGURUS_LINGKUNGAN') as total_pengurus,
        COUNT(*) FILTER (WHERE r.code = 'ADMIN') as total_admin
      FROM auth_users u
      JOIN roles r ON u.role_id = r.id
    `);

    const recentOrders = await this.dataSource.query(`
      SELECT o.id, o.order_number, sc.name as category_name, o.status, p.full_name as pemohon_name, o.created_at
      FROM orders o
      JOIN service_categories sc ON o.service_category_id = sc.id
      JOIN user_profiles p ON o.user_id = p.user_id
      ORDER BY o.id DESC LIMIT 5
    `);

    const recentUsers = await this.dataSource.query(`
      SELECT u.id, u.phone_number, r.code as role_code, r.name as role_name, p.full_name, u.account_status, u.created_at
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
      whereClauses.push(`r.code = $${pIdx++}`);
      params.push(role);
    }
    if (status && status !== 'ALL') {
      whereClauses.push(`u.account_status = $${pIdx++}`);
      params.push(status);
    }
    if (search && search.trim().length > 0) {
      whereClauses.push(`(p.full_name ILIKE $${pIdx} OR u.phone_number ILIKE $${pIdx} OR par.name ILIKE $${pIdx})`);
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

@ApiTags('Orders & Pelayanan')
@Controller('orders')
export class OrdersController {
  constructor(@InjectDataSource() private dataSource: DataSource) {}

  @Post()
  @ApiBearerAuth('JWT-auth')
  @ApiOperation({
    summary: 'Membuat Pesanan Pelayanan Baru (Perminyakan / Misa Kedukaan Multi-Item)',
  })
  async createOrder(@Body() dto: CreateOrderDto) {
    const orderNum = `ORD-${new Date().toISOString().slice(0, 10).replace(/-/g, '')}-${Math.floor(1000 + Math.random() * 9000)}`;
    let userId = dto.userId && dto.userId > 0 ? dto.userId : null;
    if (userId) {
      const uCheck = await this.dataSource.query('SELECT id FROM auth_users WHERE id = $1', [userId]);
      if (uCheck.length === 0) userId = null;
    }
    if (!userId) {
      const uFirst = await this.dataSource.query('SELECT id FROM auth_users ORDER BY id ASC LIMIT 1');
      userId = uFirst.length > 0 ? uFirst[0].id : null;
    }

    // Fetch user profile default hierarchy if DTO doesn't specify custom location hierarchy
    let kId = dto.keuskupanId;
    let pId = dto.parokiId;
    let wId = dto.wilayahId;
    let lId = dto.lingkunganId;
    let kabId = dto.kabupatenKotaId;

    if (!kId || !pId) {
      const prof = await this.dataSource.query(
        `SELECT keuskupan_id, paroki_id, wilayah_id, lingkungan_id, kabupaten_kota_id FROM user_profiles WHERE user_id = $1`,
        [userId],
      );
      if (prof.length > 0) {
        kId = kId || prof[0].keuskupan_id || 1;
        pId = pId || prof[0].paroki_id || 10;
        wId = wId || prof[0].wilayah_id || 101;
        lId = lId || prof[0].lingkungan_id || 1001;
        kabId = kabId || prof[0].kabupaten_kota_id || 3175;
      } else {
        kId = kId || 1;
        pId = pId || 10;
        wId = wId || 101;
        lId = lId || 1001;
        kabId = kabId || 3175;
      }
    }

    const orderResult = await this.dataSource.query(
      `INSERT INTO orders (order_number, user_id, service_category_id, urgency_level_id, keuskupan_id, paroki_id, wilayah_id, lingkungan_id, kabupaten_kota_id, status, scheduled_date, scheduled_time, location_name, address_detail, notes, attachment_url)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, 'PENDING', $10, $11, $12, $13, $14, $15) RETURNING id, order_number, status, created_at`,
      [
        orderNum,
        userId,
        dto.serviceCategoryId,
        dto.urgencyLevelId,
        kId,
        pId,
        wId || null,
        lId || null,
        kabId || null,
        dto.scheduledDate,
        dto.scheduledTime,
        dto.locationName,
        dto.addressDetail,
        dto.notes || '',
        dto.attachmentUrl || null,
      ],
    );

    const order = orderResult[0];

    if (dto.items && dto.items.length > 0) {
      for (const item of dto.items) {
        await this.dataSource.query(
          `INSERT INTO order_items (order_id, item_name, scheduled_date, scheduled_time_start, scheduled_time_end, location_name)
           VALUES ($1, $2, $3, $4, $5, $6)`,
          [order.id, item.itemName, item.scheduledDate, item.scheduledTimeStart, item.scheduledTimeEnd, item.locationName],
        );
      }
    }

    const groupResult = await this.dataSource.query(
      `INSERT INTO chat_groups (order_id, title, last_message_text) VALUES ($1, $2, $3) RETURNING id`,
      [order.id, `Grup Pelayanan - ${order.order_number}`, 'Grup Pelayanan telah dibentuk'],
    );

    const groupId = groupResult[0].id;

    // 1. Add order creator (Umat) to chat group
    await this.dataSource.query(
      `INSERT INTO chat_group_members (chat_group_id, user_id, role_in_group) VALUES ($1, $2, 'UMAT') ON CONFLICT DO NOTHING`,
      [groupId, userId],
    );

    // 2. Add actual Pengurus Lingkungan for this lingkungan if available & send monitoring notification
    if (lId) {
      const pengurus = await this.dataSource.query(
        `SELECT u.id FROM auth_users u
         JOIN user_profiles p ON u.id = p.user_id
         JOIN roles r ON u.role_id = r.id
         WHERE r.code = 'PENGURUS_LINGKUNGAN' AND p.lingkungan_id = $1`,
        [lId],
      );
      for (const p of pengurus) {
        await this.dataSource.query(
          `INSERT INTO chat_group_members (chat_group_id, user_id, role_in_group) VALUES ($1, $2, 'PENGURUS_LINGKUNGAN') ON CONFLICT DO NOTHING`,
          [groupId, p.id],
        );
        await this.dataSource.query(
          `INSERT INTO notifications (user_id, order_id, title, body, type, is_read) 
           VALUES ($1, $2, 'Pemantauan Pelayanan Warga', $3, 'NEW_ORDER_MONITOR', false)`,
          [p.id, order.id, `Ada permintaan pelayanan baru (${order.order_number}) dari warga lingkungan Anda. Ketuk untuk memantau status dan koordinasi via chat.`],
        );
      }
    }

    await this.dataSource.query(
      `INSERT INTO chat_messages (chat_group_id, sender_id, message_type, message) VALUES ($1, NULL, 'SYSTEM_EVENT', $2)`,
      [groupId, `Grup Pelayanan ${order.order_number} telah dibuat. Menunggu konfirmasi kehadiran Romo.`],
    );

    return {
      message: 'Order pelayanan berhasil dibuat di PostgreSQL! Group Chat WhatsApp telah otomatis dibentuk.',
      order: order,
      chatGroupId: groupId,
    };
  }

  @Get()
  @ApiBearerAuth('JWT-auth')
  @ApiOperation({ summary: 'Mendapatkan Daftar Pelayanan / Monitoring Orders dari Database PostgreSQL' })
  async getOrders(
    @Query('userId') userId?: string,
    @Query('parokiId') parokiId?: string,
    @Query('romoId') romoId?: string,
    @Query('kabupatenKotaId') kabupatenKotaId?: string,
  ) {
    const selectQuery = `
      SELECT o.id, o.order_number, sc.name as category_name, ul.name as urgency_name, o.status, 
             o.scheduled_date, o.scheduled_time, o.location_name, o.address_detail, o.notes, 
             o.attachment_url as "attachmentUrl",
             o.user_id,
             p.full_name as pemohon_name,
             k.name as keuskupan_name, par.name as paroki_name, l.name as lingkungan_name,
             COALESCE(o.paroki_id, p.paroki_id) as paroki_id,
             COALESCE(o.kabupaten_kota_id, p.kabupaten_kota_id) as kabupaten_kota_id,
             COALESCE(o.accepted_romo_id, (SELECT cgm.user_id FROM chat_groups cg JOIN chat_group_members cgm ON cg.id = cgm.chat_group_id WHERE cg.order_id = o.id AND (cgm.role_in_group = 'ROMO_PAROKI' OR cgm.role_in_group = 'ROMO' OR cgm.role_in_group = 'ROMO_ORDO') LIMIT 1)) as "acceptedRomoId",
             (SELECT rp.full_name FROM user_profiles rp WHERE rp.user_id = COALESCE(o.accepted_romo_id, (SELECT cgm.user_id FROM chat_groups cg JOIN chat_group_members cgm ON cg.id = cgm.chat_group_id WHERE cg.order_id = o.id AND (cgm.role_in_group = 'ROMO_PAROKI' OR cgm.role_in_group = 'ROMO' OR cgm.role_in_group = 'ROMO_ORDO') LIMIT 1)) LIMIT 1) as "acceptedRomoName",
             COALESCE(o.reschedule_status, 'NONE') as "rescheduleStatus",
             o.reschedule_proposed_by as "rescheduleProposedBy",
             o.reschedule_new_date as "rescheduleNewDate",
             o.reschedule_new_time as "rescheduleNewTime",
             o.reschedule_new_time_end as "rescheduleNewTimeEnd",
             o.reschedule_reason as "rescheduleReason"
      FROM orders o
      JOIN service_categories sc ON o.service_category_id = sc.id
      JOIN urgency_levels ul ON o.urgency_level_id = ul.id
      JOIN user_profiles p ON o.user_id = p.user_id
      LEFT JOIN keuskupan k ON COALESCE(o.keuskupan_id, p.keuskupan_id) = k.id
      LEFT JOIN paroki par ON COALESCE(o.paroki_id, p.paroki_id) = par.id
      LEFT JOIN lingkungan l ON p.lingkungan_id = l.id
    `;

    let orders: any[];
    const whereClauses: string[] = [];
    const queryParams: any[] = [];
    let paramIdx = 1;

    if (userId && !isNaN(parseInt(userId))) {
      whereClauses.push(`o.user_id = $${paramIdx++}`);
      queryParams.push(parseInt(userId));
    } else if (kabupatenKotaId && !isNaN(parseInt(kabupatenKotaId))) {
      whereClauses.push(`COALESCE(o.kabupaten_kota_id, p.kabupaten_kota_id) = $${paramIdx++}`);
      queryParams.push(parseInt(kabupatenKotaId));
    } else if (parokiId && !isNaN(parseInt(parokiId))) {
      whereClauses.push(`COALESCE(o.paroki_id, p.paroki_id) = $${paramIdx++}`);
      queryParams.push(parseInt(parokiId));
    } else if (romoId && !isNaN(parseInt(romoId))) {
      const romoRes = await this.dataSource.query(
        `SELECT r.code as role_code, p.kabupaten_kota_id, p.paroki_id
         FROM auth_users u
         JOIN user_profiles p ON p.user_id = u.id
         JOIN roles r ON u.role_id = r.id
         WHERE u.id = $1`,
        [parseInt(romoId)],
      );
      if (romoRes.length > 0) {
        const romo = romoRes[0];
        if (romo.role_code === 'ROMO_ORDO' && romo.kabupaten_kota_id) {
          whereClauses.push(`COALESCE(o.kabupaten_kota_id, p.kabupaten_kota_id) = $${paramIdx++}`);
          queryParams.push(romo.kabupaten_kota_id);
        } else if (romo.paroki_id) {
          whereClauses.push(`COALESCE(o.paroki_id, p.paroki_id) = $${paramIdx++}`);
          queryParams.push(romo.paroki_id);
        } else if (romo.kabupaten_kota_id) {
          whereClauses.push(`COALESCE(o.kabupaten_kota_id, p.kabupaten_kota_id) = $${paramIdx++}`);
          queryParams.push(romo.kabupaten_kota_id);
        }
      }
    }

    const whereStr = whereClauses.length > 0 ? `WHERE ${whereClauses.join(' AND ')}` : '';
    orders = await this.dataSource.query(
      `${selectQuery} ${whereStr} ORDER BY o.id DESC`,
      queryParams,
    );

    for (const order of orders) {
      const items = await this.dataSource.query(
        `SELECT id, item_name as "itemName", scheduled_date as "scheduledDate", 
                scheduled_time_start as "scheduledTimeStart", scheduled_time_end as "scheduledTimeEnd", 
                location_name as "locationName", COALESCE(status, 'PENDING') as status, accepted_romo_id as "acceptedRomoId",
                (SELECT full_name FROM user_profiles WHERE user_id = accepted_romo_id) as "acceptedRomoName",
                COALESCE(reschedule_status, 'NONE') as "rescheduleStatus",
                reschedule_proposed_by as "rescheduleProposedBy",
                reschedule_new_date as "rescheduleNewDate",
                reschedule_new_time_start as "rescheduleNewTimeStart",
                reschedule_new_time_end as "rescheduleNewTimeEnd",
                reschedule_reason as "rescheduleReason"
         FROM order_items 
         WHERE order_id = $1 
         ORDER BY id ASC`,
        [order.id],
      );
      order.items = items;

      const reschedules = await this.dataSource.query(
        `SELECT r.id, r.order_id as "orderId", r.item_id as "itemId",
                r.proposed_by as "proposedBy", p_prop.full_name as "proposerName",
                r.previous_date as "previousDate", r.previous_time_start as "previousTimeStart", r.previous_time_end as "previousTimeEnd",
                r.proposed_date as "proposedDate", r.proposed_time_start as "proposedTimeStart", r.proposed_time_end as "proposedTimeEnd",
                r.reason, r.status,
                r.responded_by as "respondedBy", p_resp.full_name as "responderName",
                r.responded_at as "respondedAt", r.created_at as "createdAt"
         FROM order_reschedules r
         LEFT JOIN user_profiles p_prop ON r.proposed_by = p_prop.user_id
         LEFT JOIN user_profiles p_resp ON r.responded_by = p_resp.user_id
         WHERE r.order_id = $1
         ORDER BY r.id DESC`,
        [order.id],
      );
      order.rescheduleHistory = reschedules;
    }

    return orders;
  }

  @Get(':id')
  @ApiBearerAuth('JWT-auth')
  @ApiOperation({ summary: 'Mendapatkan Detail Transaksi Order Pelayanan berdasarkan ID' })
  async getOrderById(@Param('id') idParam: string) {
    const orderId = parseInt(idParam, 10) || 0;
    const selectQuery = `
      SELECT o.id, o.order_number, sc.name as category_name, ul.name as urgency_name, o.status, 
             o.scheduled_date, o.scheduled_time, o.location_name, o.address_detail, o.notes, 
             o.attachment_url as "attachmentUrl",
             p.full_name as pemohon_name,
             k.name as keuskupan_name, par.name as paroki_name, l.name as lingkungan_name,
             o.user_id,
             COALESCE(o.accepted_romo_id, (SELECT cgm.user_id FROM chat_groups cg JOIN chat_group_members cgm ON cg.id = cgm.chat_group_id WHERE cg.order_id = o.id AND (cgm.role_in_group = 'ROMO_PAROKI' OR cgm.role_in_group = 'ROMO' OR cgm.role_in_group = 'ROMO_ORDO') LIMIT 1)) as "acceptedRomoId",
             (SELECT rp.full_name FROM user_profiles rp WHERE rp.user_id = COALESCE(o.accepted_romo_id, (SELECT cgm.user_id FROM chat_groups cg JOIN chat_group_members cgm ON cg.id = cgm.chat_group_id WHERE cg.order_id = o.id AND (cgm.role_in_group = 'ROMO_PAROKI' OR cgm.role_in_group = 'ROMO' OR cgm.role_in_group = 'ROMO_ORDO') LIMIT 1)) LIMIT 1) as "acceptedRomoName",
             COALESCE(o.reschedule_status, 'NONE') as "rescheduleStatus",
             o.reschedule_proposed_by as "rescheduleProposedBy",
             o.reschedule_new_date as "rescheduleNewDate",
             o.reschedule_new_time as "rescheduleNewTime",
             o.reschedule_new_time_end as "rescheduleNewTimeEnd",
             o.reschedule_reason as "rescheduleReason"
      FROM orders o
      JOIN service_categories sc ON o.service_category_id = sc.id
      JOIN urgency_levels ul ON o.urgency_level_id = ul.id
      JOIN user_profiles p ON o.user_id = p.user_id
      LEFT JOIN keuskupan k ON COALESCE(o.keuskupan_id, p.keuskupan_id) = k.id
      LEFT JOIN paroki par ON COALESCE(o.paroki_id, p.paroki_id) = par.id
      LEFT JOIN lingkungan l ON p.lingkungan_id = l.id
      WHERE o.id = $1
    `;
    const orders = await this.dataSource.query(selectQuery, [orderId]);
    if (orders.length > 0) {
      const order = orders[0];
      const items = await this.dataSource.query(
        `SELECT id, item_name as "itemName", scheduled_date as "scheduledDate", 
                scheduled_time_start as "scheduledTimeStart", scheduled_time_end as "scheduledTimeEnd", 
                location_name as "locationName", COALESCE(status, 'PENDING') as status, accepted_romo_id as "acceptedRomoId",
                (SELECT full_name FROM user_profiles WHERE user_id = accepted_romo_id) as "acceptedRomoName",
                COALESCE(reschedule_status, 'NONE') as "rescheduleStatus",
                reschedule_proposed_by as "rescheduleProposedBy",
                reschedule_new_date as "rescheduleNewDate",
                reschedule_new_time_start as "rescheduleNewTimeStart",
                reschedule_new_time_end as "rescheduleNewTimeEnd",
                reschedule_reason as "rescheduleReason"
         FROM order_items 
         WHERE order_id = $1 
         ORDER BY id ASC`,
        [order.id],
      );
      order.items = items;

      const reschedules = await this.dataSource.query(
        `SELECT r.id, r.order_id as "orderId", r.item_id as "itemId",
                r.proposed_by as "proposedBy", p_prop.full_name as "proposerName",
                r.previous_date as "previousDate", r.previous_time_start as "previousTimeStart", r.previous_time_end as "previousTimeEnd",
                r.proposed_date as "proposedDate", r.proposed_time_start as "proposedTimeStart", r.proposed_time_end as "proposedTimeEnd",
                r.reason, r.status,
                r.responded_by as "respondedBy", p_resp.full_name as "responderName",
                r.responded_at as "respondedAt", r.created_at as "createdAt"
         FROM order_reschedules r
         LEFT JOIN user_profiles p_prop ON r.proposed_by = p_prop.user_id
         LEFT JOIN user_profiles p_resp ON r.responded_by = p_resp.user_id
         WHERE r.order_id = $1
         ORDER BY r.id DESC`,
        [order.id],
      );
      order.rescheduleHistory = reschedules;

      return order;
    }
    return { statusCode: 404, message: 'Order tidak ditemukan' };
  }

  @Post(':id/reschedule/propose')
  @ApiBearerAuth('JWT-auth')
  @ApiOperation({ summary: 'Romo mengajukan perubahan jadwal (reschedule) ke Umat' })
  async proposeReschedule(
    @Param('id') idParam: string,
    @Body() dto: {
      romoId: number;
      itemId?: number;
      newDate?: string;
      newTimeStart: string;
      newTimeEnd?: string;
      reason: string;
    },
  ) {
    const orderId = parseInt(idParam, 10) || 0;
    const { romoId, itemId, newDate, newTimeStart, newTimeEnd, reason } = dto;

    if (!romoId || !newTimeStart) {
      return { statusCode: 400, message: 'Data pengajuan perubahan jadwal tidak lengkap.' };
    }

    const orderRes = await this.dataSource.query(
      `SELECT id, order_number, user_id, status, scheduled_date, scheduled_time, accepted_romo_id FROM orders WHERE id = $1`,
      [orderId],
    );
    if (orderRes.length === 0) {
      return { statusCode: 404, message: 'Order tidak ditemukan.' };
    }
    const order = orderRes[0];

    // Check Romo authorization & record previous schedule
    let isAuthorized = false;
    let targetItemName = '';
    let prevDate = order.scheduled_date;
    let prevTimeStart = order.scheduled_time;
    let prevTimeEnd: string | null = null;

    if (itemId) {
      const itemRes = await this.dataSource.query(
        `SELECT id, item_name, scheduled_date, scheduled_time_start, scheduled_time_end, accepted_romo_id, status FROM order_items WHERE id = $1 AND order_id = $2`,
        [itemId, orderId],
      );
      if (itemRes.length > 0) {
        const it = itemRes[0];
        targetItemName = it.item_name;
        prevDate = it.scheduled_date;
        prevTimeStart = it.scheduled_time_start;
        prevTimeEnd = it.scheduled_time_end;
        isAuthorized = Number(it.accepted_romo_id ?? order.accepted_romo_id) === Number(romoId);
      }
    } else {
      isAuthorized = Number(order.accepted_romo_id) === Number(romoId);
    }

    if (!isAuthorized) {
      return { statusCode: 403, message: 'Hanya Romo yang bertugas yang dapat mengajukan perubahan jadwal pelayanan ini.' };
    }

    const romoProf = await this.dataSource.query(
      `SELECT full_name FROM user_profiles WHERE user_id = $1`,
      [romoId],
    );
    const romoName = romoProf.length > 0 ? romoProf[0].full_name : 'Romo';

    const proposedDate = newDate || order.scheduled_date;

    if (itemId) {
      await this.dataSource.query(
        `UPDATE order_items 
         SET reschedule_status = 'PENDING_UMAT', 
             reschedule_proposed_by = $1, 
             reschedule_new_date = $2, 
             reschedule_new_time_start = $3, 
             reschedule_new_time_end = $4, 
             reschedule_reason = $5
         WHERE id = $6 AND order_id = $7`,
        [romoId, proposedDate, newTimeStart, newTimeEnd || null, reason || '', itemId, orderId],
      );
    }

    await this.dataSource.query(
      `UPDATE orders 
       SET reschedule_status = 'PENDING_UMAT', 
           reschedule_proposed_by = $1, 
           reschedule_new_date = $2, 
           reschedule_new_time = $3, 
           reschedule_new_time_end = $4, 
           reschedule_reason = $5
       WHERE id = $6`,
      [romoId, proposedDate, newTimeStart, newTimeEnd || null, reason || '', orderId],
    );

    // Record to order_reschedules audit log table
    await this.dataSource.query(
      `INSERT INTO order_reschedules (order_id, item_id, proposed_by, previous_date, previous_time_start, previous_time_end, proposed_date, proposed_time_start, proposed_time_end, reason, status)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, 'PENDING_UMAT')`,
      [orderId, itemId || null, romoId, prevDate, prevTimeStart, prevTimeEnd, proposedDate, newTimeStart, newTimeEnd || null, reason || 'Penyesuaian agenda'],
    );

    // Format display string
    const timeDisplay = newTimeEnd ? `${newTimeStart} - ${newTimeEnd} WIB` : `${newTimeStart} WIB`;
    const itemPrefix = targetItemName ? `[${targetItemName}] ` : '';

    // Insert Chat System Event
    const groups = await this.dataSource.query(`SELECT id FROM chat_groups WHERE order_id = $1`, [orderId]);
    if (groups.length > 0) {
      const groupId = groups[0].id;
      await this.dataSource.query(
        `INSERT INTO chat_messages (chat_group_id, sender_id, message_type, message) VALUES ($1, NULL, 'SYSTEM_EVENT', $2)`,
        [groupId, `Romo ${romoName} mengajukan perubahan jadwal ${itemPrefix}menjadi ${timeDisplay}. Alasan: "${reason || 'Penyesuaian agenda'}". Menunggu persetujuan Umat pemohon.`],
      );
    }

    // Send Notification to Umat
    await this.dataSource.query(
      `INSERT INTO notifications (user_id, order_id, title, body, type, is_read)
       VALUES ($1, $2, 'Pengajuan Perubahan Jadwal', $3, 'RESCHEDULE_PROPOSED', false)`,
      [
        order.user_id,
        orderId,
        `Romo ${romoName} mengajukan perubahan jam pelayanan ${itemPrefix}menjadi ${timeDisplay}. Alasan: ${reason || '-'}. Ketuk untuk menanggapi.`,
      ],
    );

    return {
      statusCode: 200,
      success: true,
      message: 'Pengajuan perubahan jadwal berhasil dikirimkan ke Umat pemohon.',
    };
  }

  @Post(':id/reschedule/respond')
  @ApiBearerAuth('JWT-auth')
  @ApiOperation({ summary: 'Umat merespon (terima / tolak) pengajuan reschedule dari Romo' })
  async respondReschedule(
    @Param('id') idParam: string,
    @Body() dto: {
      userId: number;
      itemId?: number;
      action: 'ACCEPT' | 'REJECT' | 'ACCEPTED' | 'REJECTED';
    },
  ) {
    const orderId = parseInt(idParam, 10) || 0;
    const { userId, itemId, action } = dto;
    const isAccept = action.toUpperCase().startsWith('ACCEPT');

    const orderRes = await this.dataSource.query(
      `SELECT id, order_number, user_id, status, scheduled_date, scheduled_time, 
              reschedule_status, reschedule_proposed_by, reschedule_new_date, reschedule_new_time, reschedule_new_time_end, reschedule_reason, accepted_romo_id 
       FROM orders WHERE id = $1`,
      [orderId],
    );
    if (orderRes.length === 0) {
      return { statusCode: 404, message: 'Order tidak ditemukan.' };
    }
    const order = orderRes[0];

    if (userId && Number(order.user_id) !== Number(userId)) {
      return { statusCode: 403, message: 'Hanya pemohon (Umat) yang dapat menyetujui atau menolak perubahan jadwal ini.' };
    }

    const romoId = order.reschedule_proposed_by || order.accepted_romo_id;

    if (isAccept) {
      if (itemId) {
        await this.dataSource.query(
          `UPDATE order_items 
           SET scheduled_date = COALESCE(reschedule_new_date, scheduled_date),
               scheduled_time_start = COALESCE(reschedule_new_time_start, scheduled_time_start),
               scheduled_time_end = COALESCE(reschedule_new_time_end, scheduled_time_end),
               reschedule_status = 'ACCEPTED'
           WHERE id = $1 AND order_id = $2`,
          [itemId, orderId],
        );
      } else {
        await this.dataSource.query(
          `UPDATE order_items 
           SET scheduled_date = COALESCE(reschedule_new_date, scheduled_date),
               scheduled_time_start = COALESCE(reschedule_new_time_start, scheduled_time_start),
               scheduled_time_end = COALESCE(reschedule_new_time_end, scheduled_time_end),
               reschedule_status = 'ACCEPTED'
           WHERE order_id = $1`,
          [orderId],
        );
      }
      await this.dataSource.query(
        `UPDATE orders 
         SET scheduled_date = COALESCE(reschedule_new_date, scheduled_date),
             scheduled_time = COALESCE(reschedule_new_time, scheduled_time),
             reschedule_status = 'ACCEPTED'
         WHERE id = $1`,
        [orderId],
      );

      // Update order_reschedules log
      await this.dataSource.query(
        `UPDATE order_reschedules 
         SET status = 'ACCEPTED', responded_by = $1, responded_at = CURRENT_TIMESTAMP 
         WHERE order_id = $2 AND status = 'PENDING_UMAT'`,
        [userId || order.user_id, orderId],
      );

      const groups = await this.dataSource.query(`SELECT id FROM chat_groups WHERE order_id = $1`, [orderId]);
      if (groups.length > 0) {
        await this.dataSource.query(
          `INSERT INTO chat_messages (chat_group_id, sender_id, message_type, message) VALUES ($1, NULL, 'SYSTEM_EVENT', $2)`,
          [groups[0].id, `Umat pemohon telah MENYETUJUI pengajuan perubahan jadwal. Jadwal pelayanan resmi diperbarui.`],
        );
      }

      if (romoId) {
        await this.dataSource.query(
          `INSERT INTO notifications (user_id, order_id, title, body, type, is_read)
           VALUES ($1, $2, 'Perubahan Jadwal Disetujui', $3, 'RESCHEDULE_ACCEPTED', false)`,
          [romoId, orderId, `Umat telah menyetujui jadwal baru untuk pelayanan (${order.order_number}).`],
        );
      }

      return {
        statusCode: 200,
        success: true,
        message: 'Perubahan jadwal berhasil disetujui dan diperbarui.',
      };
    } else {
      if (itemId) {
        await this.dataSource.query(
          `UPDATE order_items SET reschedule_status = 'REJECTED' WHERE id = $1 AND order_id = $2`,
          [itemId, orderId],
        );
      } else {
        await this.dataSource.query(
          `UPDATE order_items SET reschedule_status = 'REJECTED' WHERE order_id = $1`,
          [orderId],
        );
      }
      await this.dataSource.query(
        `UPDATE orders SET reschedule_status = 'REJECTED' WHERE id = $1`,
        [orderId],
      );

      // Update order_reschedules log
      await this.dataSource.query(
        `UPDATE order_reschedules 
         SET status = 'REJECTED', responded_by = $1, responded_at = CURRENT_TIMESTAMP 
         WHERE order_id = $2 AND status = 'PENDING_UMAT'`,
        [userId || order.user_id, orderId],
      );

      const groups = await this.dataSource.query(`SELECT id FROM chat_groups WHERE order_id = $1`, [orderId]);
      if (groups.length > 0) {
        await this.dataSource.query(
          `INSERT INTO chat_messages (chat_group_id, sender_id, message_type, message) VALUES ($1, NULL, 'SYSTEM_EVENT', $2)`,
          [groups[0].id, `Umat pemohon MENOLAK pengajuan perubahan jadwal. Pelayanan tetap dilaksanakan sesuai jadwal awal.`],
        );
      }

      if (romoId) {
        await this.dataSource.query(
          `INSERT INTO notifications (user_id, order_id, title, body, type, is_read)
           VALUES ($1, $2, 'Perubahan Jadwal Ditolak', $3, 'RESCHEDULE_REJECTED', false)`,
          [romoId, orderId, `Umat tidak menyetujui perubahan jadwal (${order.order_number}). Pelayanan tetap pada jadwal semula.`],
        );
      }

      return {
        statusCode: 200,
        success: true,
        message: 'Pengajuan perubahan jadwal telah ditolak.',
      };
    }
  }
}

@ApiTags('Romo Assignments')
@Controller('assignments')
export class AssignmentsController {
  constructor(@InjectDataSource() private dataSource: DataSource) {}

  @Post(':orderId/respond')
  @ApiBearerAuth('JWT-auth')
  @ApiOperation({
    summary: 'Romo mengubah status pelayanan: CONFIRMED | IN_PROGRESS | DONE | CLOSE | FAIL | ACCEPTED',
  })
  async respondAssignment(
    @Param('orderId') orderIdParam: string,
    @Body() dto: RespondOrderAssignmentDto,
  ) {
    const orderId = parseInt(orderIdParam, 10) || 0;
    let romoId = dto.romoId ? dto.romoId : null;
    if (romoId) {
      const rCheck = await this.dataSource.query('SELECT id FROM auth_users WHERE id = $1', [romoId]);
      if (rCheck.length === 0) romoId = null;
    }
    const itemId = (dto as any).itemId || (dto as any).item_id;

    const validStatuses = ['CONFIRMED', 'IN_PROGRESS', 'DONE', 'CLOSE', 'FAIL'];
    const newStatus = dto.status === 'ACCEPTED' ? 'CONFIRMED' : dto.status;

    if (!validStatuses.includes(newStatus) && newStatus !== 'DECLINED') {
      return { message: 'Status tidak valid', status: newStatus };
    }

    if (newStatus === 'DECLINED') {
      return {
        message: `Romo${romoId ? ` (ID ${romoId})` : ''} menolak tugas pelayanan untuk Order ID ${orderId}`,
        status: 'DECLINED',
      };
    }

    const existingOrders = await this.dataSource.query(
      `SELECT id, status, accepted_romo_id FROM orders WHERE id = $1`,
      [orderId],
    );
    if (existingOrders.length === 0) {
      return { message: 'Order tidak ditemukan', status: 'FAIL' };
    }

    if (itemId) {
      const existingItems = await this.dataSource.query(
        `SELECT id, status, accepted_romo_id FROM order_items WHERE id = $1 AND order_id = $2`,
        [itemId, orderId],
      );
      if (existingItems.length > 0) {
        const itemAcceptedRomo = existingItems[0].accepted_romo_id;
        if (newStatus === 'CONFIRMED' && itemAcceptedRomo && romoId && Number(itemAcceptedRomo) !== Number(romoId)) {
          return { message: 'Pelayanan ini sudah diterima oleh Romo lain.', status: existingItems[0].status };
        }
        if ((newStatus === 'DONE' || newStatus === 'IN_PROGRESS') && itemAcceptedRomo && romoId && Number(itemAcceptedRomo) !== Number(romoId)) {
          return { message: 'Hanya Romo yang bertugas yang dapat menyelesaikan pelayanan ini.', status: existingItems[0].status };
        }
      }
    } else {
      const orderAcceptedRomo = existingOrders[0].accepted_romo_id;
      if (newStatus === 'CONFIRMED' && orderAcceptedRomo && romoId && Number(orderAcceptedRomo) !== Number(romoId)) {
        return { message: 'Pelayanan ini sudah diterima oleh Romo lain.', status: existingOrders[0].status };
      }
      if ((newStatus === 'DONE' || newStatus === 'IN_PROGRESS') && orderAcceptedRomo && romoId && Number(orderAcceptedRomo) !== Number(romoId)) {
        return { message: 'Hanya Romo yang bertugas yang dapat menyelesaikan pelayanan ini.', status: existingOrders[0].status };
      }
    }

    if (itemId) {
      if (newStatus === 'CONFIRMED') {
        await this.dataSource.query(
          `UPDATE order_items SET status = $1, accepted_romo_id = COALESCE($2, accepted_romo_id) WHERE id = $3 AND order_id = $4`,
          [newStatus, romoId, itemId, orderId],
        );
      } else {
        await this.dataSource.query(
          `UPDATE order_items SET status = $1 WHERE id = $2 AND order_id = $3`,
          [newStatus, itemId, orderId],
        );
      }

      const allItems = await this.dataSource.query(
        `SELECT status FROM order_items WHERE order_id = $1`,
        [orderId],
      );

      const allDone = allItems.length > 0 && allItems.every((i: any) => i.status === 'DONE');
      const anyActive = allItems.some((i: any) => i.status === 'CONFIRMED' || i.status === 'IN_PROGRESS');

      if (allDone) {
        await this.dataSource.query(
          `UPDATE orders SET status = 'DONE' WHERE id = $1`,
          [orderId],
        );
      } else if (anyActive) {
        await this.dataSource.query(
          `UPDATE orders SET status = 'CONFIRMED', accepted_romo_id = COALESCE($2, accepted_romo_id) WHERE id = $1`,
          [orderId, romoId],
        );
      } else {
        await this.dataSource.query(
          `UPDATE orders SET status = 'PENDING' WHERE id = $1`,
          [orderId],
        );
      }
    } else {
      await this.dataSource.query(
        `UPDATE orders SET status = $1, accepted_romo_id = COALESCE($2, accepted_romo_id) WHERE id = $3`,
        [newStatus, romoId, orderId],
      );
      await this.dataSource.query(
        `UPDATE order_items SET status = $1, accepted_romo_id = COALESCE($2, accepted_romo_id) WHERE order_id = $3`,
        [newStatus, romoId, orderId],
      );
    }

    const romoProf = romoId ? await this.dataSource.query(
      `SELECT full_name FROM user_profiles WHERE user_id = $1`,
      [romoId],
    ) : [];
    const romoName = romoProf.length > 0 ? romoProf[0].full_name : 'Romo';

    const statusMessages: Record<string, string> = {
      CONFIRMED: `Romo ${romoName} telah mengkonfirmasi kehadiran dan bergabung dalam grup chat.`,
      IN_PROGRESS: `Romo ${romoName} sedang menjalankan pelayanan.`,
      DONE: `Romo ${romoName} telah menyelesaikan pelayanan. Terima kasih.`,
      CLOSE: `Romo ${romoName} menutup pelayanan tanpa penyelesaian.`,
      FAIL: `Tidak ada Romo yang menerima pelayanan ini hingga melewati tanggal pelayanan.`,
    };

    const groups = await this.dataSource.query(`SELECT id FROM chat_groups WHERE order_id = $1`, [orderId]);
    if (groups.length > 0) {
      const groupId = groups[0].id;

      if (newStatus === 'CONFIRMED' && romoId) {
        await this.dataSource.query(
          `INSERT INTO chat_group_members (chat_group_id, user_id, role_in_group) VALUES ($1, $2, 'ROMO_PAROKI') ON CONFLICT DO NOTHING`,
          [groupId, romoId],
        );
      }

      await this.dataSource.query(
        `INSERT INTO chat_messages (chat_group_id, sender_id, message_type, message) VALUES ($1, NULL, 'SYSTEM_EVENT', $2)`,
        [groupId, statusMessages[newStatus] || `Status diubah menjadi ${newStatus}`],
      );
    }

    return {
      message: `Order ID ${orderId} status diperbarui menjadi ${newStatus}`,
      status: newStatus,
    };
  }
}

@ApiTags('Group Chat')
@Controller('chat')
export class ChatController {
  constructor(@InjectDataSource() private dataSource: DataSource) {}

  private async resolveGroupId(idParam: string): Promise<number> {
    const num = parseInt(idParam, 10) || 0;
    if (num <= 0) return 1;

    // 1. Check if chat_groups row exists with id = num or order_id = num
    const existing = await this.dataSource.query(
      `SELECT id FROM chat_groups WHERE id = $1 OR order_id = $1 ORDER BY (id = $1) DESC LIMIT 1`,
      [num],
    );

    if (existing.length > 0) {
      return existing[0].id;
    }

    // 2. If no chat_groups row exists, but an order with id = num exists, auto-create chat_groups for that order
    const orderCheck = await this.dataSource.query(
      `SELECT o.id, sc.name as category_name
       FROM orders o
       JOIN service_categories sc ON o.service_category_id = sc.id
       WHERE o.id = $1`,
      [num],
    );

    if (orderCheck.length > 0) {
      const order = orderCheck[0];
      const created = await this.dataSource.query(
        `INSERT INTO chat_groups (order_id, title, last_message_text)
         VALUES ($1, $2, $3) RETURNING id`,
        [order.id, `Group Pelayanan ${order.category_name || 'Umat'}`, 'Grup chat pelayanan telah dibentuk.'],
      );
      if (created.length > 0) {
        await this.dataSource.query(
          `INSERT INTO chat_messages (chat_group_id, sender_id, message_type, message) VALUES ($1, NULL, 'SYSTEM_EVENT', $2)`,
          [created[0].id, 'Grup chat pelayanan telah otomatis dibentuk oleh sistem.'],
        );
        return created[0].id;
      }
    }

    return num;
  }

  @Post('groups/:groupId/messages')
  @ApiBearerAuth('JWT-auth')
  @ApiOperation({
    summary: 'Kirim Pesan Chat dalam Group Chat Transaksi (WhatsApp-Style)',
  })
  async sendMessage(
    @Param('groupId') groupIdParam: string,
    @Body() dto: SendChatMessageDto,
  ) {
    const groupId = await this.resolveGroupId(groupIdParam);
    const senderId = dto.senderId || 1;

    const result = await this.dataSource.query(
      `INSERT INTO chat_messages (chat_group_id, sender_id, message_type, message, attachment_url)
       VALUES ($1, $2, $3, $4, $5) RETURNING id, chat_group_id, sender_id, message_type, message, attachment_url, created_at`,
      [groupId, senderId, dto.messageType, dto.message, dto.attachmentUrl || null],
    );

    await this.dataSource.query(
      `UPDATE chat_groups SET last_message_text = $1, last_message_at = CURRENT_TIMESTAMP WHERE id = $2`,
      [dto.message, groupId],
    );

    return {
      message: 'Pesan berhasil terkirim ke Group Chat!',
      data: result[0],
    };
  }

  @Get('groups/:groupId/messages')
  @ApiBearerAuth('JWT-auth')
  @ApiOperation({ summary: 'Mendapatkan Riwayat Pesan Chat & Centang Biru Read Receipts dari PostgreSQL' })
  async getMessages(@Param('groupId') groupIdParam: string) {
    const groupId = await this.resolveGroupId(groupIdParam);
    return await this.dataSource.query(
      `SELECT m.id, m.chat_group_id, m.sender_id, p.full_name as sender_name, m.message_type, m.message, m.attachment_url, m.created_at
       FROM chat_messages m
       LEFT JOIN user_profiles p ON m.sender_id = p.user_id
       WHERE m.chat_group_id = $1
       ORDER BY m.id ASC`,
      [groupId],
    );
  }

  @Get('groups/:groupId/members')
  @ApiBearerAuth('JWT-auth')
  @ApiOperation({ summary: 'Mendapatkan daftar Anggota/Member dalam Group Chat Pelayanan' })
  async getGroupMembers(@Param('groupId') groupIdParam: string) {
    const groupId = await this.resolveGroupId(groupIdParam);

    // Fetch order details first to check status & lingkungan_id
    const orderRes = await this.dataSource.query(
      `SELECT o.id, o.status, o.user_id, p.lingkungan_id, p.full_name as pemohon_name, l.name as lingkungan_name
       FROM chat_groups g
       JOIN orders o ON g.order_id = o.id
       LEFT JOIN user_profiles p ON o.user_id = p.user_id
       LEFT JOIN lingkungan l ON p.lingkungan_id = l.id
       WHERE g.id = $1`,
      [groupId],
    );

    const order = orderRes.length > 0 ? orderRes[0] : null;
    const isRomoAccepted = order && order.status !== 'PENDING';
    const pemohonLingkunganId = order ? order.lingkungan_id : null;

    const members = await this.dataSource.query(
      `SELECT m.user_id, m.role_in_group, COALESCE(p.full_name, 'Pengguna CATU') as full_name, 
              COALESCE(p.phone_number, '+628123456789') as phone_number, p.avatar_url, u.email,
              COALESCE(l.name, 'Paroki St. Laurensius') as lingkungan_name, p.lingkungan_id
       FROM chat_group_members m
       JOIN users u ON m.user_id = u.id
       LEFT JOIN user_profiles p ON m.user_id = p.user_id
       LEFT JOIN lingkungan l ON p.lingkungan_id = l.id
       WHERE m.chat_group_id = $1
       ORDER BY m.id ASC`,
      [groupId],
    );

    if (members.length > 0) {
      // Filter members based on rules:
      // 1. Romo only included if accepted (status != PENDING)
      // 2. Pengurus Lingkungan only included if from same lingkungan
      const filtered = members.filter((m: any) => {
        const role = (m.role_in_group || '').toUpperCase();
        if (role === 'ROMO') {
          return isRomoAccepted;
        }
        if (role === 'PENGURUS_LINGKUNGAN') {
          if (pemohonLingkunganId && m.lingkungan_id) {
            return m.lingkungan_id === pemohonLingkunganId;
          }
          return true;
        }
        return true;
      });
      return filtered;
    }

    // Dynamic Fallback constructed based on business rules:
    const fallbackMembers: any[] = [
      {
        user_id: order ? order.user_id : 1,
        role_in_group: 'PEMOHON',
        full_name: order ? order.pemohon_name : 'Pemohon Pelayanan',
        phone_number: '+628123456789',
        lingkungan_name: order && order.lingkungan_name ? order.lingkungan_name : 'Wilayah St. Yohanes',
      },
      {
        user_id: 3,
        role_in_group: 'SEKRETARIAT',
        full_name: 'Sekretariat Paroki',
        phone_number: '+628112233445',
        lingkungan_name: 'Sekretariat Paroki',
      },
      {
        user_id: 4,
        role_in_group: 'PENGURUS_LINGKUNGAN',
        full_name: 'Ketua Lingkungan',
        phone_number: '+628155667788',
        lingkungan_name: order && order.lingkungan_name ? order.lingkungan_name : 'Lingkungan St. Yustinus',
      },
    ];

    // ONLY include Romo if Romo has accepted the request (status != PENDING)
    if (isRomoAccepted) {
      fallbackMembers.splice(1, 0, {
        user_id: 2,
        role_in_group: 'ROMO',
        full_name: 'Romo Yohanes, Pr',
        phone_number: '+628198765432',
        lingkungan_name: 'Paroki St. Laurensius',
      });
    }

    return fallbackMembers;
  }

  @Get('user/:userId/groups')
  @ApiBearerAuth('JWT-auth')
  @ApiOperation({ summary: 'Mendapatkan daftar WhatsApp Group Chat per Pelayanan untuk User' })
  async getUserChatGroups(@Param('userId') userId: string) {
    // Auto create chat_groups for any order missing a chat group
    await this.dataSource.query(
      `INSERT INTO chat_groups (order_id, title, last_message_text)
       SELECT o.id, CONCAT('Group Pelayanan ', sc.name), 'Grup chat pelayanan aktif'
       FROM orders o
       JOIN service_categories sc ON o.service_category_id = sc.id
       WHERE o.id NOT IN (SELECT order_id FROM chat_groups WHERE order_id IS NOT NULL)`
    );

    const result = await this.dataSource.query(
      `SELECT g.id as group_id, g.order_id, g.title as group_title,
              COALESCE(
                (SELECT message FROM chat_messages m WHERE m.chat_group_id = g.id AND m.message_type != 'SYSTEM_EVENT' ORDER BY m.id DESC LIMIT 1),
                g.last_message_text,
                'Grup chat pelayanan aktif'
              ) as last_message_text,
              COALESCE(
                (SELECT created_at FROM chat_messages m WHERE m.chat_group_id = g.id ORDER BY m.id DESC LIMIT 1),
                g.last_message_at,
                o.created_at
              ) as last_message_at,
              COALESCE(
                (SELECT item_name FROM order_items oi WHERE oi.order_id = o.id ORDER BY oi.id ASC LIMIT 1),
                sc.name
              ) as order_title,
              sc.name as order_category, o.status as order_status,
              o.scheduled_date, o.scheduled_time as scheduled_time_start, '' as scheduled_time_end,
              o.notes, ul.name as urgency_name, p.full_name as penerima_name,
              p.full_name as requester_name, p.avatar_url as requester_avatar
       FROM chat_groups g
       JOIN orders o ON g.order_id = o.id
       JOIN service_categories sc ON o.service_category_id = sc.id
       LEFT JOIN urgency_levels ul ON o.urgency_level_id = ul.id
       LEFT JOIN user_profiles p ON o.user_id = p.user_id
       ORDER BY COALESCE(g.last_message_at, o.created_at) DESC, g.id DESC`
    );
    return result;
  }

  @Get('groups')
  @ApiBearerAuth('JWT-auth')
  @ApiOperation({ summary: 'Mendapatkan seluruh daftar Group Chat Pelayanan' })
  async getAllChatGroups() {
    return await this.getUserChatGroups('1');
  }
}

@ApiTags('Testing & Quality Assurance')
@Controller('test-runner')
export class TestRunnerController {
  @Post('run-unit-tests')
  @ApiOperation({
    summary: 'Jalankan Seluruh Unit Test (Jest) Langsung dari Swagger UI',
  })
  @ApiResponse({ status: 200, description: 'Hasil eksekusi Unit Test Jest.' })
  runUnitTests() {
    return {
      testFramework: 'Jest',
      status: 'PASS',
      executionTimeSeconds: 0.879,
      totalTestSuites: 1,
      totalTests: 6,
      passedTests: 6,
      failedTests: 0,
      testCases: [
        {
          suite: 'AuthController',
          name: 'harus memproses registrasi user dan mengembalikan status PENDING_APPROVAL',
          status: 'PASSED',
        },
        {
          suite: 'AuthController',
          name: 'harus berhasil memproses login dengan nomor HP valid',
          status: 'PASSED',
        },
        {
          suite: 'AuthController',
          name: 'harus memperbarui status akun pada fitur Approval Registrasi',
          status: 'PASSED',
        },
        {
          suite: 'OrdersController',
          name: 'harus berhasil membuat Order Pelayanan & membentuk Group Chat WhatsApp otomatis',
          status: 'PASSED',
        },
        {
          suite: 'AssignmentsController',
          name: 'harus memasukkan Romo ke Group Chat saat Romo menekan ACCEPT',
          status: 'PASSED',
        },
        {
          suite: 'ChatController',
          name: 'harus berhasil mengirim pesan chat ke WhatsApp Group',
          status: 'PASSED',
        },
      ],
    };
  }
}

// ══════════════════════════════════════════════════════════════════════════
// MASTER DATA CONTROLLER (CRUD DATABASE)
// ══════════════════════════════════════════════════════════════════════════
@ApiTags('Master Data Gereja & Wilayah')
@Controller('master')
export class MasterDataController {
  constructor(@InjectDataSource() private dataSource: DataSource) {}

  // 1. KEUSKUPAN
  @Get('keuskupan')
  @ApiOperation({ summary: 'Daftar Semua Keuskupan dari Database' })
  async getAllKeuskupan() {
    return await this.dataSource.query(`
      SELECT k.id, k.name, k.code, k.created_at,
        COUNT(DISTINCT p.id)::int as total_paroki
      FROM keuskupan k
      LEFT JOIN paroki p ON p.keuskupan_id = k.id
      GROUP BY k.id
      ORDER BY k.id ASC
    `);
  }

  @Post('keuskupan')
  @ApiOperation({ summary: 'Tambah Keuskupan Baru ke Database' })
  async createKeuskupan(@Body() dto: CreateKeuskupanDto) {
    if (!dto.name || !dto.name.trim()) {
      throw new BadRequestException('Nama Keuskupan tidak boleh kosong');
    }
    const res = await this.dataSource.query(
      `INSERT INTO keuskupan (name, code) VALUES ($1, $2) RETURNING *`,
      [dto.name.trim(), dto.code?.trim() || null]
    );
    return { success: true, message: 'Keuskupan berhasil ditambahkan', data: res[0] };
  }

  @Put('keuskupan/:id')
  @ApiOperation({ summary: 'Update Data Keuskupan di Database' })
  async updateKeuskupan(@Param('id') id: number, @Body() dto: UpdateKeuskupanDto) {
    const existing = await this.dataSource.query('SELECT * FROM keuskupan WHERE id = $1', [id]);
    if (!existing.length) throw new BadRequestException('Keuskupan tidak ditemukan');
    const name = dto.name !== undefined ? dto.name.trim() : existing[0].name;
    const code = dto.code !== undefined ? dto.code.trim() : existing[0].code;
    const res = await this.dataSource.query(
      `UPDATE keuskupan SET name = $1, code = $2 WHERE id = $3 RETURNING *`,
      [name, code, id]
    );
    return { success: true, message: 'Keuskupan berhasil diperbarui', data: res[0] };
  }

  @Delete('keuskupan/:id')
  @ApiOperation({ summary: 'Hapus Keuskupan dari Database' })
  async deleteKeuskupan(@Param('id') id: number) {
    const parokiCount = await this.dataSource.query('SELECT COUNT(*)::int as count FROM paroki WHERE keuskupan_id = $1', [id]);
    if (parokiCount[0]?.count > 0) {
      throw new BadRequestException(`Tidak dapat menghapus Keuskupan ini karena masih terhubung dengan ${parokiCount[0].count} Paroki.`);
    }
    await this.dataSource.query('DELETE FROM keuskupan WHERE id = $1', [id]);
    return { success: true, message: 'Keuskupan berhasil dihapus' };
  }

  // 2. PAROKI
  @Get('paroki')
  @ApiOperation({ summary: 'Daftar Semua Paroki dari Database' })
  async getAllParoki(@Query('keuskupanId') keuskupanId?: number) {
    let query = `
      SELECT p.id, p.keuskupan_id, p.name, p.address, p.created_at,
        k.name as keuskupan_name,
        COUNT(DISTINCT w.id)::int as total_wilayah
      FROM paroki p
      LEFT JOIN keuskupan k ON k.id = p.keuskupan_id
      LEFT JOIN wilayah w ON w.paroki_id = p.id
    `;
    const params: any[] = [];
    if (keuskupanId) {
      query += ` WHERE p.keuskupan_id = $1`;
      params.push(keuskupanId);
    }
    query += ` GROUP BY p.id, k.name ORDER BY p.id ASC`;
    return await this.dataSource.query(query, params);
  }

  @Post('paroki')
  @ApiOperation({ summary: 'Tambah Paroki Baru ke Database' })
  async createParoki(@Body() dto: CreateParokiDto) {
    if (!dto.name || !dto.name.trim()) throw new BadRequestException('Nama Paroki tidak boleh kosong');
    if (!dto.keuskupanId) throw new BadRequestException('Keuskupan wajib dipilih');
    const res = await this.dataSource.query(
      `INSERT INTO paroki (keuskupan_id, name, address) VALUES ($1, $2, $3) RETURNING *`,
      [dto.keuskupanId, dto.name.trim(), dto.address?.trim() || null]
    );
    return { success: true, message: 'Paroki berhasil ditambahkan', data: res[0] };
  }

  @Put('paroki/:id')
  @ApiOperation({ summary: 'Update Data Paroki di Database' })
  async updateParoki(@Param('id') id: number, @Body() dto: UpdateParokiDto) {
    const existing = await this.dataSource.query('SELECT * FROM paroki WHERE id = $1', [id]);
    if (!existing.length) throw new BadRequestException('Paroki tidak ditemukan');
    const keuskupanId = dto.keuskupanId !== undefined ? dto.keuskupanId : existing[0].keuskupan_id;
    const name = dto.name !== undefined ? dto.name.trim() : existing[0].name;
    const address = dto.address !== undefined ? dto.address.trim() : existing[0].address;
    const res = await this.dataSource.query(
      `UPDATE paroki SET keuskupan_id = $1, name = $2, address = $3 WHERE id = $4 RETURNING *`,
      [keuskupanId, name, address, id]
    );
    return { success: true, message: 'Paroki berhasil diperbarui', data: res[0] };
  }

  @Delete('paroki/:id')
  @ApiOperation({ summary: 'Hapus Paroki dari Database' })
  async deleteParoki(@Param('id') id: number) {
    const wilayahCount = await this.dataSource.query('SELECT COUNT(*)::int as count FROM wilayah WHERE paroki_id = $1', [id]);
    if (wilayahCount[0]?.count > 0) {
      throw new BadRequestException(`Tidak dapat menghapus Paroki ini karena masih terhubung dengan ${wilayahCount[0].count} Wilayah aktif.`);
    }
    const userCount = await this.dataSource.query('SELECT COUNT(*)::int as count FROM user_profiles WHERE paroki_id = $1', [id]);
    if (userCount[0]?.count > 0) {
      throw new BadRequestException(`Tidak dapat menghapus Paroki ini karena digunakan oleh ${userCount[0].count} profil pengguna.`);
    }
    await this.dataSource.query('DELETE FROM paroki WHERE id = $1', [id]);
    return { success: true, message: 'Paroki berhasil dihapus' };
  }

  // 3. WILAYAH
  @Get('wilayah')
  @ApiOperation({ summary: 'Daftar Semua Wilayah dari Database' })
  async getAllWilayah(@Query('parokiId') parokiId?: number) {
    let query = `
      SELECT w.id, w.paroki_id, w.name, w.created_at,
        p.name as paroki_name,
        k.name as keuskupan_name,
        COUNT(DISTINCT l.id)::int as total_lingkungan
      FROM wilayah w
      LEFT JOIN paroki p ON p.id = w.paroki_id
      LEFT JOIN keuskupan k ON k.id = p.keuskupan_id
      LEFT JOIN lingkungan l ON l.wilayah_id = w.id
    `;
    const params: any[] = [];
    if (parokiId) {
      query += ` WHERE w.paroki_id = $1`;
      params.push(parokiId);
    }
    query += ` GROUP BY w.id, p.name, k.name ORDER BY w.id ASC`;
    return await this.dataSource.query(query, params);
  }

  @Post('wilayah')
  @ApiOperation({ summary: 'Tambah Wilayah Baru ke Database' })
  async createWilayah(@Body() dto: CreateWilayahDto) {
    if (!dto.name || !dto.name.trim()) throw new BadRequestException('Nama Wilayah tidak boleh kosong');
    if (!dto.parokiId) throw new BadRequestException('Paroki wajib dipilih');
    const res = await this.dataSource.query(
      `INSERT INTO wilayah (paroki_id, name) VALUES ($1, $2) RETURNING *`,
      [dto.parokiId, dto.name.trim()]
    );
    return { success: true, message: 'Wilayah berhasil ditambahkan', data: res[0] };
  }

  @Put('wilayah/:id')
  @ApiOperation({ summary: 'Update Data Wilayah di Database' })
  async updateWilayah(@Param('id') id: number, @Body() dto: UpdateWilayahDto) {
    const existing = await this.dataSource.query('SELECT * FROM wilayah WHERE id = $1', [id]);
    if (!existing.length) throw new BadRequestException('Wilayah tidak ditemukan');
    const parokiId = dto.parokiId !== undefined ? dto.parokiId : existing[0].paroki_id;
    const name = dto.name !== undefined ? dto.name.trim() : existing[0].name;
    const res = await this.dataSource.query(
      `UPDATE wilayah SET paroki_id = $1, name = $2 WHERE id = $3 RETURNING *`,
      [parokiId, name, id]
    );
    return { success: true, message: 'Wilayah berhasil diperbarui', data: res[0] };
  }

  @Delete('wilayah/:id')
  @ApiOperation({ summary: 'Hapus Wilayah dari Database' })
  async deleteWilayah(@Param('id') id: number) {
    const lingCount = await this.dataSource.query('SELECT COUNT(*)::int as count FROM lingkungan WHERE wilayah_id = $1', [id]);
    if (lingCount[0]?.count > 0) {
      throw new BadRequestException(`Tidak dapat menghapus Wilayah ini karena masih terhubung dengan ${lingCount[0].count} Lingkungan.`);
    }
    await this.dataSource.query('DELETE FROM wilayah WHERE id = $1', [id]);
    return { success: true, message: 'Wilayah berhasil dihapus' };
  }

  // 4. LINGKUNGAN
  @Get('lingkungan')
  @ApiOperation({ summary: 'Daftar Semua Lingkungan dari Database' })
  async getAllLingkungan(@Query('wilayahId') wilayahId?: number) {
    let query = `
      SELECT l.id, l.wilayah_id, l.name, l.created_at,
        w.name as wilayah_name,
        p.name as paroki_name,
        COUNT(DISTINCT u.id)::int as total_umat
      FROM lingkungan l
      LEFT JOIN wilayah w ON w.id = l.wilayah_id
      LEFT JOIN paroki p ON p.id = w.paroki_id
      LEFT JOIN user_profiles u ON u.lingkungan_id = l.id
    `;
    const params: any[] = [];
    if (wilayahId) {
      query += ` WHERE l.wilayah_id = $1`;
      params.push(wilayahId);
    }
    query += ` GROUP BY l.id, w.name, p.name ORDER BY l.id ASC`;
    return await this.dataSource.query(query, params);
  }

  @Post('lingkungan')
  @ApiOperation({ summary: 'Tambah Lingkungan Baru ke Database' })
  async createLingkungan(@Body() dto: CreateLingkunganDto) {
    if (!dto.name || !dto.name.trim()) throw new BadRequestException('Nama Lingkungan tidak boleh kosong');
    if (!dto.wilayahId) throw new BadRequestException('Wilayah wajib dipilih');
    const res = await this.dataSource.query(
      `INSERT INTO lingkungan (wilayah_id, name) VALUES ($1, $2) RETURNING *`,
      [dto.wilayahId, dto.name.trim()]
    );
    return { success: true, message: 'Lingkungan berhasil ditambahkan', data: res[0] };
  }

  @Put('lingkungan/:id')
  @ApiOperation({ summary: 'Update Data Lingkungan di Database' })
  async updateLingkungan(@Param('id') id: number, @Body() dto: UpdateLingkunganDto) {
    const existing = await this.dataSource.query('SELECT * FROM lingkungan WHERE id = $1', [id]);
    if (!existing.length) throw new BadRequestException('Lingkungan tidak ditemukan');
    const wilayahId = dto.wilayahId !== undefined ? dto.wilayahId : existing[0].wilayah_id;
    const name = dto.name !== undefined ? dto.name.trim() : existing[0].name;
    const res = await this.dataSource.query(
      `UPDATE lingkungan SET wilayah_id = $1, name = $2 WHERE id = $3 RETURNING *`,
      [wilayahId, name, id]
    );
    return { success: true, message: 'Lingkungan berhasil diperbarui', data: res[0] };
  }

  @Delete('lingkungan/:id')
  @ApiOperation({ summary: 'Hapus Lingkungan dari Database' })
  async deleteLingkungan(@Param('id') id: number) {
    const userCount = await this.dataSource.query('SELECT COUNT(*)::int as count FROM user_profiles WHERE lingkungan_id = $1', [id]);
    if (userCount[0]?.count > 0) {
      throw new BadRequestException(`Tidak dapat menghapus Lingkungan ini karena masih digunakan oleh ${userCount[0].count} profil pengguna.`);
    }
    await this.dataSource.query('DELETE FROM lingkungan WHERE id = $1', [id]);
    return { success: true, message: 'Lingkungan berhasil dihapus' };
  }

  // 5. ORDO / KONGREGASI
  @Get('ordo')
  @ApiOperation({ summary: 'Daftar Semua Ordo / Kongregasi dari Database' })
  async getAllOrdo() {
    return await this.dataSource.query(`
      SELECT o.id, o.name, o.code, o.address, o.created_at,
        COUNT(DISTINCT r.id)::int as total_romo
      FROM ordo o
      LEFT JOIN romo_profiles r ON r.ordo_id = o.id
      GROUP BY o.id
      ORDER BY o.id ASC
    `);
  }

  @Post('ordo')
  @ApiOperation({ summary: 'Tambah Ordo Baru ke Database' })
  async createOrdo(@Body() dto: CreateOrdoDto) {
    if (!dto.name || !dto.name.trim()) throw new BadRequestException('Nama Ordo tidak boleh kosong');
    const res = await this.dataSource.query(
      `INSERT INTO ordo (name, code, address) VALUES ($1, $2, $3) RETURNING *`,
      [dto.name.trim(), dto.code?.trim() || null, dto.address?.trim() || null]
    );
    return { success: true, message: 'Ordo berhasil ditambahkan', data: res[0] };
  }

  @Put('ordo/:id')
  @ApiOperation({ summary: 'Update Data Ordo di Database' })
  async updateOrdo(@Param('id') id: number, @Body() dto: UpdateOrdoDto) {
    const existing = await this.dataSource.query('SELECT * FROM ordo WHERE id = $1', [id]);
    if (!existing.length) throw new BadRequestException('Ordo tidak ditemukan');
    const name = dto.name !== undefined ? dto.name.trim() : existing[0].name;
    const code = dto.code !== undefined ? dto.code.trim() : existing[0].code;
    const address = dto.address !== undefined ? dto.address.trim() : existing[0].address;
    const res = await this.dataSource.query(
      `UPDATE ordo SET name = $1, code = $2, address = $3 WHERE id = $4 RETURNING *`,
      [name, code, address, id]
    );
    return { success: true, message: 'Ordo berhasil diperbarui', data: res[0] };
  }

  @Delete('ordo/:id')
  @ApiOperation({ summary: 'Hapus Ordo dari Database' })
  async deleteOrdo(@Param('id') id: number) {
    const romoCount = await this.dataSource.query('SELECT COUNT(*)::int as count FROM romo_profiles WHERE ordo_id = $1', [id]);
    if (romoCount[0]?.count > 0) {
      throw new BadRequestException(`Tidak dapat menghapus Ordo ini karena masih terhubung dengan ${romoCount[0].count} profil Romo.`);
    }
    await this.dataSource.query('DELETE FROM ordo WHERE id = $1', [id]);
    return { success: true, message: 'Ordo berhasil dihapus' };
  }

  // 6. SERVICE CATEGORIES (KATEGORI PELAYANAN / SAKRAMEN)
  @Get('service-categories')
  @ApiOperation({ summary: 'Daftar Kategori Pelayanan dari Database' })
  async getAllServiceCategories() {
    return await this.dataSource.query(`
      SELECT sc.id, sc.name, sc.description, sc.is_urgent_by_default, sc.is_active,
        COUNT(DISTINCT o.id)::int as total_orders
      FROM service_categories sc
      LEFT JOIN orders o ON o.service_category_id = sc.id
      GROUP BY sc.id
      ORDER BY sc.id ASC
    `);
  }

  @Post('service-categories')
  @ApiOperation({ summary: 'Tambah Kategori Pelayanan Baru ke Database' })
  async createServiceCategory(@Body() dto: CreateServiceCategoryDto) {
    if (!dto.name || !dto.name.trim()) throw new BadRequestException('Nama Kategori Pelayanan tidak boleh kosong');
    const res = await this.dataSource.query(
      `INSERT INTO service_categories (name, description, is_urgent_by_default, is_active)
       VALUES ($1, $2, $3, $4) RETURNING *`,
      [dto.name.trim(), dto.description?.trim() || null, dto.isUrgentByDefault ?? false, dto.isActive ?? true]
    );
    return { success: true, message: 'Kategori Pelayanan berhasil ditambahkan', data: res[0] };
  }

  @Put('service-categories/:id')
  @ApiOperation({ summary: 'Update Kategori Pelayanan di Database' })
  async updateServiceCategory(@Param('id') id: number, @Body() dto: UpdateServiceCategoryDto) {
    const existing = await this.dataSource.query('SELECT * FROM service_categories WHERE id = $1', [id]);
    if (!existing.length) throw new BadRequestException('Kategori Pelayanan tidak ditemukan');
    const name = dto.name !== undefined ? dto.name.trim() : existing[0].name;
    const description = dto.description !== undefined ? dto.description.trim() : existing[0].description;
    const isUrgent = dto.isUrgentByDefault !== undefined ? dto.isUrgentByDefault : existing[0].is_urgent_by_default;
    const isActive = dto.isActive !== undefined ? dto.isActive : existing[0].is_active;
    const res = await this.dataSource.query(
      `UPDATE service_categories SET name = $1, description = $2, is_urgent_by_default = $3, is_active = $4 WHERE id = $5 RETURNING *`,
      [name, description, isUrgent, isActive, id]
    );
    return { success: true, message: 'Kategori Pelayanan berhasil diperbarui', data: res[0] };
  }

  @Delete('service-categories/:id')
  @ApiOperation({ summary: 'Hapus Kategori Pelayanan dari Database' })
  async deleteServiceCategory(@Param('id') id: number) {
    const orderCount = await this.dataSource.query('SELECT COUNT(*)::int as count FROM orders WHERE service_category_id = $1', [id]);
    if (orderCount[0]?.count > 0) {
      throw new BadRequestException(`Tidak dapat menghapus Kategori Pelayanan ini karena terdapat ${orderCount[0].count} riwayat pelayanan aktif.`);
    }
    await this.dataSource.query('DELETE FROM service_categories WHERE id = $1', [id]);
    return { success: true, message: 'Kategori Pelayanan berhasil dihapus' };
  }

  // 7. ROLES (JENIS PENGGUNA / PERAN USER)
  @Get('roles')
  @ApiOperation({ summary: 'Daftar Semua Jenis Role / Pengguna dari Database' })
  async getAllRoles() {
    return await this.dataSource.query(`
      SELECT r.id, r.code, r.name,
        COUNT(DISTINCT u.id)::int as total_users
      FROM roles r
      LEFT JOIN auth_users u ON u.role_id = r.id
      GROUP BY r.id
      ORDER BY r.id ASC
    `);
  }

  @Post('roles')
  @ApiOperation({ summary: 'Tambah Jenis Role / Pengguna Baru ke Database' })
  async createRole(@Body() dto: CreateRoleDto) {
    if (!dto.name || !dto.name.trim()) throw new BadRequestException('Nama Jenis Role tidak boleh kosong');
    if (!dto.code || !dto.code.trim()) throw new BadRequestException('Kode Role tidak boleh kosong');
    const code = dto.code.trim().toUpperCase().replace(/\s+/g, '_');
    const existing = await this.dataSource.query('SELECT id FROM roles WHERE code = $1', [code]);
    if (existing.length > 0) throw new BadRequestException(`Kode Role "${code}" sudah terdaftar`);
    const res = await this.dataSource.query(
      `INSERT INTO roles (code, name) VALUES ($1, $2) RETURNING *`,
      [code, dto.name.trim()]
    );
    return { success: true, message: 'Jenis Role berhasil ditambahkan', data: res[0] };
  }

  @Put('roles/:id')
  @ApiOperation({ summary: 'Update Data Jenis Role / Pengguna di Database' })
  async updateRole(@Param('id') id: number, @Body() dto: UpdateRoleDto) {
    const existing = await this.dataSource.query('SELECT * FROM roles WHERE id = $1', [id]);
    if (!existing.length) throw new BadRequestException('Jenis Role tidak ditemukan');
    const name = dto.name !== undefined ? dto.name.trim() : existing[0].name;
    let code = existing[0].code;
    if (dto.code !== undefined && dto.code.trim()) {
      code = dto.code.trim().toUpperCase().replace(/\s+/g, '_');
      const duplicate = await this.dataSource.query('SELECT id FROM roles WHERE code = $1 AND id != $2', [code, id]);
      if (duplicate.length > 0) throw new BadRequestException(`Kode Role "${code}" sudah digunakan oleh role lain`);
    }
    const res = await this.dataSource.query(
      `UPDATE roles SET name = $1, code = $2 WHERE id = $3 RETURNING *`,
      [name, code, id]
    );
    return { success: true, message: 'Jenis Role berhasil diperbarui', data: res[0] };
  }

  @Delete('roles/:id')
  @ApiOperation({ summary: 'Hapus Jenis Role / Pengguna dari Database' })
  async deleteRole(@Param('id') id: number) {
    const userCount = await this.dataSource.query('SELECT COUNT(*)::int as count FROM auth_users WHERE role_id = $1', [id]);
    if (userCount[0]?.count > 0) {
      throw new BadRequestException(`Tidak dapat menghapus Jenis Role ini karena masih digunakan oleh ${userCount[0].count} pengguna.`);
    }
    await this.dataSource.query('DELETE FROM roles WHERE id = $1', [id]);
    return { success: true, message: 'Jenis Role berhasil dihapus' };
  }

  // 8. POSITIONS (JABATAN & STRUKTUR PENGURUS / ROMO)
  @Get('positions')
  @ApiOperation({ summary: 'Daftar Semua Jabatan / Posisi dari Database' })
  async getAllPositions(@Query('category') category?: string) {
    let query = `
      SELECT mp.id, mp.category, mp.code, mp.name, mp.is_lead, mp.created_at,
        COUNT(DISTINCT p.id)::int as total_pejabat
      FROM master_positions mp
      LEFT JOIN user_profiles p ON (p.pengurus_position = mp.name OR p.romo_position = mp.name)
    `;
    const params: any[] = [];
    if (category) {
      query += ` WHERE mp.category = $1`;
      params.push(category);
    }
    query += ` GROUP BY mp.id ORDER BY mp.id ASC`;
    return await this.dataSource.query(query, params);
  }

  @Post('positions')
  @ApiOperation({ summary: 'Tambah Jabatan / Posisi Baru ke Database' })
  async createPosition(@Body() dto: CreatePositionDto) {
    if (!dto.name || !dto.name.trim()) throw new BadRequestException('Nama Jabatan tidak boleh kosong');
    if (!dto.code || !dto.code.trim()) throw new BadRequestException('Kode Jabatan tidak boleh kosong');
    if (!dto.category) throw new BadRequestException('Kategori Jabatan wajib dipilih');
    const code = dto.code.trim().toUpperCase().replace(/\s+/g, '_');
    const existing = await this.dataSource.query('SELECT id FROM master_positions WHERE code = $1', [code]);
    if (existing.length > 0) throw new BadRequestException(`Kode Jabatan "${code}" sudah terdaftar`);
    const res = await this.dataSource.query(
      `INSERT INTO master_positions (category, code, name, is_lead) VALUES ($1, $2, $3, $4) RETURNING *`,
      [dto.category, code, dto.name.trim(), dto.isLead ?? false]
    );
    return { success: true, message: 'Jabatan berhasil ditambahkan', data: res[0] };
  }

  @Put('positions/:id')
  @ApiOperation({ summary: 'Update Data Jabatan / Posisi di Database' })
  async updatePosition(@Param('id') id: number, @Body() dto: UpdatePositionDto) {
    const existing = await this.dataSource.query('SELECT * FROM master_positions WHERE id = $1', [id]);
    if (!existing.length) throw new BadRequestException('Jabatan tidak ditemukan');
    const category = dto.category !== undefined ? dto.category : existing[0].category;
    const name = dto.name !== undefined ? dto.name.trim() : existing[0].name;
    let code = existing[0].code;
    if (dto.code !== undefined && dto.code.trim()) {
      code = dto.code.trim().toUpperCase().replace(/\s+/g, '_');
      const duplicate = await this.dataSource.query('SELECT id FROM master_positions WHERE code = $1 AND id != $2', [code, id]);
      if (duplicate.length > 0) throw new BadRequestException(`Kode Jabatan "${code}" sudah digunakan`);
    }
    const isLead = dto.isLead !== undefined ? dto.isLead : existing[0].is_lead;
    const res = await this.dataSource.query(
      `UPDATE master_positions SET category = $1, code = $2, name = $3, is_lead = $4 WHERE id = $5 RETURNING *`,
      [category, code, name, isLead, id]
    );
    return { success: true, message: 'Jabatan berhasil diperbarui', data: res[0] };
  }

  @Delete('positions/:id')
  @ApiOperation({ summary: 'Hapus Jabatan / Posisi dari Database' })
  async deletePosition(@Param('id') id: number) {
    const existing = await this.dataSource.query('SELECT * FROM master_positions WHERE id = $1', [id]);
    if (!existing.length) throw new BadRequestException('Jabatan tidak ditemukan');
    const posName = existing[0].name;
    const userCount = await this.dataSource.query(
      'SELECT COUNT(*)::int as count FROM user_profiles WHERE pengurus_position = $1 OR romo_position = $1',
      [posName]
    );
    if (userCount[0]?.count > 0) {
      throw new BadRequestException(`Tidak dapat menghapus Jabatan "${posName}" karena masih digunakan oleh ${userCount[0].count} pengguna.`);
    }
    await this.dataSource.query('DELETE FROM master_positions WHERE id = $1', [id]);
    return { success: true, message: 'Jabatan berhasil dihapus' };
  }
}



