import { BadRequestException, Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { InjectDataSource } from '@nestjs/typeorm';
import { DataSource } from 'typeorm';
import {
  DEFAULT_KOORDINATOR_AFTER_MINUTES,
  DEFAULT_ORDO_AFTER_MINUTES,
  EscalationSettings,
  SETTING_KOORDINATOR_AFTER,
  SETTING_ORDO_AFTER,
  parseMinutes,
  validateSettings,
} from './escalation-rules';

/** Parameter eskalasi pelayanan (tabel app_settings) dan kolom penanda notifikasi eskalasi di orders. */
@Injectable()
export class EscalationSettingsService implements OnModuleInit {
  private readonly logger = new Logger(EscalationSettingsService.name);

  constructor(@InjectDataSource() private readonly dataSource: DataSource) {}

  async onModuleInit() {
    try {
      await this.dataSource.query(`
        CREATE TABLE IF NOT EXISTS app_settings (
          key VARCHAR(100) PRIMARY KEY,
          value TEXT NOT NULL,
          description TEXT,
          updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
        );
        ALTER TABLE orders
          ADD COLUMN IF NOT EXISTS ordo_notified_at TIMESTAMPTZ,
          ADD COLUMN IF NOT EXISTS koordinator_notified_at TIMESTAMPTZ;
      `);
      await this.dataSource.query(
        `INSERT INTO app_settings (key, value, description) VALUES
           ($1, $2, 'Menit sejak pelayanan dibuat sampai terbuka untuk Romo Ordo'),
           ($3, $4, 'Menit sejak pelayanan dibuat sampai Koordinator diberi tahu untuk mencarikan Romo')
         ON CONFLICT (key) DO NOTHING`,
        [SETTING_ORDO_AFTER, String(DEFAULT_ORDO_AFTER_MINUTES), SETTING_KOORDINATOR_AFTER, String(DEFAULT_KOORDINATOR_AFTER_MINUTES)],
      );
    } catch (err) {
      this.logger.error(`Gagal menyiapkan parameter eskalasi: ${(err as Error).message}`);
    }
  }

  async get(): Promise<EscalationSettings> {
    const rows = await this.dataSource.query('SELECT key, value FROM app_settings WHERE key = ANY($1)', [[SETTING_ORDO_AFTER, SETTING_KOORDINATOR_AFTER]]);
    const byKey = new Map<string, string>(rows.map((r: any) => [r.key, r.value]));
    return {
      ordoAfterMinutes: parseMinutes(byKey.get(SETTING_ORDO_AFTER), DEFAULT_ORDO_AFTER_MINUTES),
      koordinatorAfterMinutes: parseMinutes(byKey.get(SETTING_KOORDINATOR_AFTER), DEFAULT_KOORDINATOR_AFTER_MINUTES),
    };
  }

  async update(next: EscalationSettings): Promise<EscalationSettings> {
    const error = validateSettings(next);
    if (error) throw new BadRequestException(error);
    for (const [key, value] of [[SETTING_ORDO_AFTER, next.ordoAfterMinutes], [SETTING_KOORDINATOR_AFTER, next.koordinatorAfterMinutes]] as const) {
      await this.dataSource.query(
        `INSERT INTO app_settings (key, value) VALUES ($1, $2)
         ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value, updated_at = CURRENT_TIMESTAMP`,
        [key, String(value)],
      );
    }
    return this.get();
  }
}
