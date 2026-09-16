import { Module, NestModule, MiddlewareConsumer } from '@nestjs/common';
import { APP_GUARD } from '@nestjs/core';
import { ConfigModule } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import { JwtModule } from '@nestjs/jwt';
import { ThrottlerModule, ThrottlerGuard } from '@nestjs/throttler';

import { DatabaseInitModule } from './database/database-init.module';
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
      signOptions: { expiresIn: '30d' },
    }),
    ThrottlerModule.forRoot([
      {
        ttl: 60000,
        limit: 300,
      },
    ]),
    DatabaseInitModule,
    FcmModule,
    HealthModule,
    AuthModule,
    OrdersModule,
    AssignmentsModule,
    ChatModule,
    NotificationsModule,
    MasterDataModule,
    NewsModule,
    TestRunnerModule,
    ApkModule,
  ],
  providers: [
    AppService,
    {
      provide: APP_GUARD,
      useClass: ThrottlerGuard,
    },
  ],
})
export class AppModule implements NestModule {
  configure(consumer: MiddlewareConsumer) {
    consumer.apply(HttpLoggerMiddleware).forRoutes('*');
  }
}
