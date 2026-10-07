import { BadRequestException, Injectable } from '@nestjs/common';
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

/** Parameter eskalasi pelayanan (tabel app_settings; tabel dan nilai awal dibuat migrasi). */
@Injectable()
export class EscalationSettingsService {
  constructor(@InjectDataSource() private readonly dataSource: DataSource) {}

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
