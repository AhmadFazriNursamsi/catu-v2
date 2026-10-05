import { Module, NestModule, MiddlewareConsumer } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import { JwtModule } from '@nestjs/jwt';
import { ThrottlerModule } from '@nestjs/throttler';

import { GLOBAL_GUARD_PROVIDERS } from './common/guards/global-guards';
import { AccessModule } from './common/access/access.module';
import { OrderEventsModule } from './modules/order-events/order-events.module';
import { EscalationModule } from './modules/escalation/escalation.module';
import { OrderRulesModule } from './modules/order-rules/order-rules.module';

import { DatabaseInitModule } from './database/database-init.module';
import { DrizzleModule } from './database/drizzle.module';
import { FcmModule } from './modules/fcm/fcm.module';
import { HealthModule } from './modules/health/health.module';
import { AuthModule } from './modules/auth/auth.module';
import { OrdersModule } from './modules/orders/orders.module';
import { AssignmentsModule } from './modules/assignments/assignments.module';
import { ChatModule } from './modules/chat/chat.module';
import { NotificationsModule } from './modules/notifications/notifications.module';
import { MasterDataModule } from './modules/master-data/master-data.module';
import { NewsModule } from './modules/news/news.module';
import { TestRunnerModule } from './modules/test-runner/test-runner.module';
import { ApkModule } from './modules/apk/apk.module';
import { ActivityLogsModule } from './modules/activity-logs/activity-logs.module';

import { AppService } from './app.service';
import { HttpLoggerMiddleware } from './logger.middleware';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
    }),
    TypeOrmModule.forRoot({
      type: 'postgres',
      host: process.env.DB_HOST || 'catu_postgres',
      port: parseInt(process.env.DB_PORT || '5432', 10),
      username: process.env.DB_USERNAME || process.env.DB_USER || 'postgres',
      password: process.env.DB_PASSWORD,
      database: process.env.DB_NAME || 'catu_v2_db',
      schema: 'public',
      autoLoadEntities: true,
      synchronize: false,
      extra: {
        max: 30,
        idleTimeoutMillis: 30000,
        connectionTimeoutMillis: 5000,
      },
    }),
    JwtModule.register({
      global: true,
      secret: process.env.JWT_SECRET,
      signOptions: { expiresIn: (process.env.JWT_EXPIRES_IN || '14d') as any },
    }),
    ThrottlerModule.forRoot([
      {
        ttl: 60000,
        limit: 300,
      },
    ]),
    AccessModule,
    OrderEventsModule,
    EscalationModule,
    OrderRulesModule,
    DatabaseInitModule,
    DrizzleModule,
    FcmModule,
    HealthModule,
    AuthModule,
    OrdersModule,
    AssignmentsModule,
    ChatModule,
    NotificationsModule,
    MasterDataModule,
    NewsModule,
    // Live Unit Test Runner hanya tersedia di luar production.
    ...(process.env.NODE_ENV === 'production' ? [] : [TestRunnerModule]),
    ApkModule,
    ActivityLogsModule,
  ],
  providers: [
    AppService,
    ...GLOBAL_GUARD_PROVIDERS,
  ],
})
export class AppModule implements NestModule {
  configure(consumer: MiddlewareConsumer) {
    consumer.apply(HttpLoggerMiddleware).forRoutes('*');
  }
}
