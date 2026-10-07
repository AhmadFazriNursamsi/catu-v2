import { Injectable, OnModuleDestroy } from '@nestjs/common';
import { Pool } from 'pg';
import { NodePgDatabase, drizzle } from 'drizzle-orm/node-postgres';
import * as schema from './schema';

@Injectable()
export class DrizzleService implements OnModuleDestroy {
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

  async onModuleDestroy(): Promise<void> {
    await this.pool.end();
  }
}
