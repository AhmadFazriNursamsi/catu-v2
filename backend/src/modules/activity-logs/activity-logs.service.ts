import { Injectable, Logger, Inject, OnModuleInit } from '@nestjs/common';
import { NodePgDatabase } from 'drizzle-orm/node-postgres';
import { desc, sql, SQL } from 'drizzle-orm';
import { DRIZZLE_DB } from '../../database/drizzle.module';
import * as schema from '../../database/schema';
import { CreateActivityLogParams, QueryActivityLogsDto } from './activity-logs.dto';

@Injectable()
export class ActivityLogsService implements OnModuleInit {
  private readonly logger = new Logger(ActivityLogsService.name);

  constructor(
    @Inject(DRIZZLE_DB)
    private readonly db: NodePgDatabase<typeof schema>,
  ) {}

  async onModuleInit() {
    try {
      const [res] = await this.db.select({ count: sql<number>`count(*)::int` }).from(schema.activityLogs);
      if (Number(res?.count) === 0) {
        await this.log({
          userName: 'System Daemon',
          userRole: 'SYSTEM',
          action: 'SYSTEM_BOOT',
          targetEntity: 'SYSTEM',
          description: 'Layanan CATU Backend & Audit Trail berhasil diinisialisasi',
          metadata: { engine: 'NestJS + Drizzle ORM', status: 'ONLINE' },
        });
      }
    } catch (_) {}
  }

  async log(params: CreateActivityLogParams): Promise<void> {
    try {
      const metadataString = params.metadata
        ? typeof params.metadata === 'string'
          ? params.metadata
          : JSON.stringify(params.metadata)
        : null;

      await this.db.insert(schema.activityLogs).values({
        userId: params.userId ?? null,
        userName: params.userName ?? null,
        userRole: params.userRole ?? null,
        action: params.action,
        targetEntity: params.targetEntity ?? null,
        targetId: params.targetId ? String(params.targetId) : null,
        description: params.description,
        ipAddress: params.ipAddress ?? null,
        userAgent: params.userAgent ?? null,
        metadata: metadataString,
      });
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : String(err);
      this.logger.warn(`Failed to record activity log: ${message}`);
    }
  }

  async findAll(query: QueryActivityLogsDto) {
    const page = Math.max(1, query.page || 1);
    const limit = Math.min(100, Math.max(1, query.limit || 20));
    const offset = (page - 1) * limit;

    const conditions: SQL[] = [];

    if (query.role) {
      conditions.push(sql`user_role = ${query.role}`);
    }
    if (query.action) {
      conditions.push(sql`action = ${query.action}`);
    }
    if (query.targetEntity) {
      conditions.push(sql`target_entity = ${query.targetEntity}`);
    }
    if (query.startDate) {
      conditions.push(sql`created_at >= ${query.startDate}::timestamp`);
    }
    if (query.endDate) {
      conditions.push(sql`created_at <= (${query.endDate}::date + interval '1 day')`);
    }
    if (query.search) {
      const searchPattern = `%${query.search}%`;
      conditions.push(
        sql`(user_name ILIKE ${searchPattern} OR description ILIKE ${searchPattern} OR target_id ILIKE ${searchPattern} OR action ILIKE ${searchPattern})`,
      );
    }

    const whereClause = conditions.length > 0 ? sql.join(conditions, sql` AND `) : undefined;

    const [countResult] = await this.db
      .select({ count: sql<number>`count(*)::int` })
      .from(schema.activityLogs)
      .where(whereClause);

    const total = countResult?.count ?? 0;

    const items = await this.db
      .select()
      .from(schema.activityLogs)
      .where(whereClause)
      .orderBy(desc(schema.activityLogs.createdAt))
      .limit(limit)
      .offset(offset);

    return {
      statusCode: 200,
      data: items,
      meta: {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit),
      },
    };
  }
}
