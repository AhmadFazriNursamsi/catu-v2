import { Injectable, Logger, OnModuleInit, OnModuleDestroy } from '@nestjs/common';
import { Pool } from 'pg';
import { NodePgDatabase, drizzle } from 'drizzle-orm/node-postgres';
import { migrate } from 'drizzle-orm/node-postgres/migrator';
import * as fs from 'fs';
import * as path from 'path';
import * as schema from './schema';

@Injectable()
export class DrizzleService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(DrizzleService.name);
  private pool: Pool;
  private _db: NodePgDatabase<typeof schema>;

  constructor() {
    this.pool = new Pool({
      host: process.env.DB_HOST || 'catu_postgres',
      port: parseInt(process.env.DB_PORT || '5432', 10),
      user: process.env.DB_USERNAME || process.env.DB_USER || 'postgres',
      password: process.env.DB_PASSWORD,
      database: process.env.DB_NAME || 'catu_v2_db',
      max: 10,
      idleTimeoutMillis: 30000,
      connectionTimeoutMillis: 5000,
    });
    this._db = drizzle(this.pool, { schema });
  }

  get db(): NodePgDatabase<typeof schema> {
    return this._db;
  }

  get client(): Pool {
    return this.pool;
  }

  private resolveMigrationsFolder(): string {
    const candidates = [
      path.resolve(process.cwd(), 'drizzle'),
      path.resolve(process.cwd(), 'backend/drizzle'),
      path.resolve(__dirname, '../../drizzle'),
      path.resolve(__dirname, '../../../drizzle'),
    ];

    for (const candidate of candidates) {
      const journalFile = path.join(candidate, 'meta/_journal.json');
      if (fs.existsSync(journalFile)) {
        return candidate;
      }
    }

    return path.resolve(process.cwd(), 'drizzle');
  }

  async onModuleInit(): Promise<void> {
    const folder = this.resolveMigrationsFolder();
    this.logger.log(`Executing Drizzle auto-migration using journal at: ${folder}`);

    try {
      await migrate(this._db, { migrationsFolder: folder });
      this.logger.log('Drizzle database migration completed successfully');
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : String(err);
      this.logger.error(`Failed to apply Drizzle migrations: ${message}`);
    }
  }

  async onModuleDestroy(): Promise<void> {
    await this.pool.end();
  }
}
