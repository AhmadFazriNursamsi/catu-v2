import { Injectable, Logger, OnModuleInit } from "@nestjs/common";
import { InjectDataSource } from "@nestjs/typeorm";
import { DataSource } from "typeorm";
import * as path from "path";
import { readFileSync, existsSync } from "fs";

/** Tabel master yang diisi dari master_data_seed.sql dengan ID eksplisit; urutan ID harus disusulkan setelah pengisian. */
const SEEDED_MASTER_TABLES = ["provinsi", "kabupaten_kota", "keuskupan", "paroki", "wilayah", "lingkungan", "ordo"];

/**
 * Pengisian data master wilayah (data besar, bukan skema). Skema, data referensi, dan perbaikan data dikelola migrasi
 * (backend/drizzle); aplikasi tidak menjalankan DDL, tidak mengubah data pengguna, dan tidak membuat akun saat start.
 */
@Injectable()
export class DatabaseInitService implements OnModuleInit {
  private readonly logger = new Logger(DatabaseInitService.name);

  constructor(@InjectDataSource() private dataSource: DataSource) {}

  async onModuleInit() {
    await this.syncFullMasterData();
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
      for (const table of SEEDED_MASTER_TABLES) {
        await this.dataSource.query(`SELECT setval(pg_get_serial_sequence('public.${table}', 'id'), GREATEST((SELECT COALESCE(MAX(id), 1) FROM public.${table}), 1))`);
      }
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
