import { Injectable, Logger, OnModuleInit } from "@nestjs/common";
import { InjectDataSource } from "@nestjs/typeorm";
import { DataSource } from "typeorm";
import * as path from "path";
import { readFileSync, existsSync } from "fs";

@Injectable()
export class DatabaseInitService implements OnModuleInit {
  private readonly logger = new Logger(DatabaseInitService.name);

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
        CREATE TABLE IF NOT EXISTS provinsi (id INT PRIMARY KEY, name VARCHAR(255) NOT NULL);
        CREATE TABLE IF NOT EXISTS kabupaten_kota (id INT PRIMARY KEY, provinsi_id INT, name VARCHAR(255) NOT NULL, type VARCHAR(50));
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

        -- Seed roles & default superadmin / admin accounts
        INSERT INTO roles (code, name) VALUES ('SUPERADMIN', 'Super Admin'), ('ADMIN', 'Administrator') ON CONFLICT (code) DO NOTHING;
        UPDATE roles SET name = 'Administrator' WHERE code = 'ADMIN';
        UPDATE auth_users SET role_id = (SELECT id FROM roles WHERE code = 'SUPERADMIN'), password_hash = '$2b$10$Tv2.dDx8z2.kprJSimWlauu7DsgGgzeAtYvhnnRC35HAtYv7xeA0C' WHERE phone_number = '6289999999999';
        INSERT INTO auth_users (phone_number, password_hash, role_id, account_status) SELECT '6288888888888', '$2b$10$Tv2.dDx8z2.kprJSimWlauu7DsgGgzeAtYvhnnRC35HAtYv7xeA0C', (SELECT id FROM roles WHERE code = 'ADMIN'), 'APPROVED' WHERE NOT EXISTS (SELECT 1 FROM auth_users WHERE phone_number = '6288888888888');
        INSERT INTO user_profiles (user_id, full_name, email) SELECT u.id, 'Administrator Sistem', 'admin@catu.id' FROM auth_users u WHERE u.phone_number = '6288888888888' AND NOT EXISTS (SELECT 1 FROM user_profiles WHERE user_id = u.id);
        INSERT INTO user_profiles (user_id, full_name, email) SELECT u.id, 'Super Admin CATU', 'admin@catu.or.id' FROM auth_users u WHERE u.phone_number = '6289999999999' AND NOT EXISTS (SELECT 1 FROM user_profiles WHERE user_id = u.id);
      `);

      // Automatically sync complete master data (Provinsi, Kota, Keuskupan, Paroki, Wilayah, Lingkungan, Ordo)
      await this.syncFullMasterData();
    } catch (e) {
      this.logger.error('Auto-migration database notice:', e);
    }
  }

  async syncFullMasterData(force = false): Promise<{ synced: boolean; message: string; counts?: any }> {
    try {
      await this.dataSource.query(`SET search_path = public, pg_catalog;`);
      const counts = await this.dataSource.query(`
        SELECT 
          (SELECT COUNT(*) FROM public.provinsi) as p_count,
          (SELECT COUNT(*) FROM public.kabupaten_kota) as k_count,
          (SELECT COUNT(*) FROM public.keuskupan) as keus_count,
          (SELECT COUNT(*) FROM public.paroki) as par_count,
          (SELECT COUNT(*) FROM public.wilayah) as w_count,
          (SELECT COUNT(*) FROM public.lingkungan) as l_count,
          (SELECT COUNT(*) FROM public.ordo) as o_count
      `);
      const pCount = parseInt(counts[0]?.p_count || '0', 10);
      const kCount = parseInt(counts[0]?.k_count || '0', 10);
      const keusCount = parseInt(counts[0]?.keus_count || '0', 10);
      const parCount = parseInt(counts[0]?.par_count || '0', 10);
      const wCount = parseInt(counts[0]?.w_count || '0', 10);
      const lCount = parseInt(counts[0]?.l_count || '0', 10);
      const oCount = parseInt(counts[0]?.o_count || '0', 10);

      const isComplete = pCount >= 34 && kCount >= 500 && wCount >= 800 && lCount >= 3500;

      if (isComplete && !force) {
        this.logger.log(`Master data already complete (provinsi: ${pCount}, kota: ${kCount}, wilayah: ${wCount}, lingkungan: ${lCount}).`);
        return { 
          synced: false, 
          message: 'Data master sudah lengkap.',
          counts: { provinsi: pCount, kabupatenKota: kCount, keuskupan: keusCount, paroki: parCount, wilayah: wCount, lingkungan: lCount, ordo: oCount }
        };
      }

      this.logger.log(`Syncing complete master data... (Current: provinsi=${pCount}, kota=${kCount}, wilayah=${wCount}, lingkungan=${lCount})`);

      const candidatePaths = [
        path.join(__dirname, 'master_data_seed.sql'),
        path.join(__dirname, '..', 'database', 'master_data_seed.sql'),
        path.join(process.cwd(), 'dist', 'database', 'master_data_seed.sql'),
        path.join(process.cwd(), 'drizzle', 'master_data_seed.sql'),
        path.join(process.cwd(), 'src', 'database', 'master_data_seed.sql'),
      ];

      let sqlContent = '';
      for (const p of candidatePaths) {
        if (existsSync(p)) {
          sqlContent = readFileSync(p, 'utf-8');
          this.logger.log(`Found master_data_seed.sql at: ${p}`);
          break;
        }
      }

      if (!sqlContent) {
        this.logger.warn('master_data_seed.sql not found in candidate paths.');
        return { synced: false, message: 'File master_data_seed.sql tidak ditemukan.' };
      }

      await this.dataSource.query(sqlContent);
      this.logger.log('Complete master data successfully seeded!');

      const updatedCounts = await this.dataSource.query(`
        SELECT 
          (SELECT COUNT(*) FROM public.provinsi) as p_count,
          (SELECT COUNT(*) FROM public.kabupaten_kota) as k_count,
          (SELECT COUNT(*) FROM public.keuskupan) as keus_count,
          (SELECT COUNT(*) FROM public.paroki) as par_count,
          (SELECT COUNT(*) FROM public.wilayah) as w_count,
          (SELECT COUNT(*) FROM public.lingkungan) as l_count,
          (SELECT COUNT(*) FROM public.ordo) as o_count
      `);

      return {
        synced: true,
        message: 'Data master berhasil disinkronisasi ke database.',
        counts: {
          provinsi: parseInt(updatedCounts[0]?.p_count || '0', 10),
          kabupatenKota: parseInt(updatedCounts[0]?.k_count || '0', 10),
          keuskupan: parseInt(updatedCounts[0]?.keus_count || '0', 10),
          paroki: parseInt(updatedCounts[0]?.par_count || '0', 10),
          wilayah: parseInt(updatedCounts[0]?.w_count || '0', 10),
          lingkungan: parseInt(updatedCounts[0]?.l_count || '0', 10),
          ordo: parseInt(updatedCounts[0]?.o_count || '0', 10),
        }
      };
    } catch (err: any) {
      this.logger.error(`Failed to sync master data: ${err.message}`, err.stack);
      return { synced: false, message: err.message };
    }
  }
}
