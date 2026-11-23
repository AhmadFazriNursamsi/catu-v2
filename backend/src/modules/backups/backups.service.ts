import { Injectable } from '@nestjs/common';
import { readFile } from 'node:fs/promises';

/** Ringkasan cadangan yang ditulis scripts/server/backup.sh (tanpa rahasia), di-mount read-only ke container. */
interface DailyBackup { stamp: string; bytes: number | null; tables: number | null; db: string; cloud: string; cloudAt: string }
interface BackupStatusFile {
  generatedAt: string;
  keepDaily: number;
  cloudEnabled: boolean;
  disk: { freeMb: number | null; usedPct: number | null };
  daily: DailyBackup[];
  deploy: { stamp: string; bytes: number | null }[];
}

const MAX_DAILY_AGE_HOURS = 26; // cron 02.15 tiap hari + kelonggaran

/** "20261123-021501" + offset zona dari generatedAt ("+07:00") → Date. */
function stampToDate(stamp: string, generatedAt: string): Date | null {
  const m = /^(\d{4})(\d{2})(\d{2})-(\d{2})(\d{2})(\d{2})/.exec(stamp);
  if (!m) return null;
  const offset = /([+-]\d{2}:\d{2}|Z)$/.exec(generatedAt)?.[1] ?? 'Z';
  const d = new Date(`${m[1]}-${m[2]}-${m[3]}T${m[4]}:${m[5]}:${m[6]}${offset}`);
  return isNaN(d.getTime()) ? null : d;
}

@Injectable()
export class BackupsService {
  private readonly file = process.env.BACKUP_STATUS_FILE || '/app/backup-status/status.json';

  async status() {
    let data: BackupStatusFile;
    try {
      data = JSON.parse(await readFile(this.file, 'utf8'));
    } catch {
      return { available: false, health: 'unknown', message: 'Ringkasan cadangan belum tersedia di server (backup-status/status.json).' };
    }
    const latest = data.daily?.[0];
    const latestAt = latest ? stampToDate(latest.stamp, data.generatedAt) : null;
    const ageHours = latestAt ? Math.round(((Date.now() - latestAt.getTime()) / 36e5) * 10) / 10 : null;
    const problems: string[] = [];
    if (!latest) problems.push('Belum ada cadangan harian.');
    else if (ageHours == null || ageHours > MAX_DAILY_AGE_HOURS) problems.push(`Cadangan harian terakhir sudah ${ageHours ?? '?'} jam yang lalu (seharusnya tiap hari).`);
    if (latest && !(latest.tables && latest.tables > 0) && latest.db) problems.push('Cadangan terakhir tidak berisi tabel.');
    if (data.cloudEnabled && latest && latest.cloud !== 'ok') problems.push('Cadangan terakhir belum tersalin ke cloud (S3).');
    if (!data.cloudEnabled) problems.push('Salinan ke cloud belum aktif: cadangan hanya ada di disk server.');
    if ((data.disk?.usedPct ?? 0) >= 90) problems.push(`Disk server hampir penuh (${data.disk.usedPct}%).`);
    const critical = !latest || (ageHours ?? 999) > MAX_DAILY_AGE_HOURS;
    return {
      available: true,
      health: critical ? 'error' : problems.length ? 'warning' : 'ok',
      problems,
      latestAgeHours: ageHours,
      ...data,
      daily: (data.daily ?? []).map((d) => ({ ...d, createdAt: stampToDate(d.stamp, data.generatedAt)?.toISOString() ?? null })),
      deploy: (data.deploy ?? []).map((d) => ({ ...d, createdAt: stampToDate(d.stamp, data.generatedAt)?.toISOString() ?? null })),
    };
  }
}
