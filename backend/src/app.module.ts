import { Module, NestModule, MiddlewareConsumer } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { JwtModule } from '@nestjs/jwt';
import {
  AuthController,
  OrdersController,
  NotificationsController,
  AssignmentsController,
  ChatController,
  TestRunnerController,
  MasterDataController,
} from './app.controller';
import { NewsController } from './news.controller';
import { NewsService } from './news.service';
import { FcmService } from './fcm.service';
import { AppService } from './app.service';
import { HttpLoggerMiddleware } from './logger.middleware';

@Module({
  imports: [
    TypeOrmModule.forRoot({
      type: 'postgres',
      host: process.env.DB_HOST || 'catu_postgres',
      port: parseInt(process.env.DB_PORT || '5432'),
      username: process.env.DB_USERNAME || process.env.DB_USER || 'postgres',
      password: process.env.DB_PASSWORD || 'postgrespassword',
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
      secret: process.env.JWT_SECRET || 'catu_v2_secure_jwt_production_secret_key_2026_@#!',
      signOptions: { expiresIn: '30d' },
    }),
  ],
  controllers: [
    AuthController,
    OrdersController,
    NotificationsController,
    AssignmentsController,
    ChatController,
    TestRunnerController,
    MasterDataController,
    NewsController,
  ],
  providers: [AppService, NewsService, FcmService],
  exports: [FcmService],
})
export class AppModule implements NestModule {
  configure(consumer: MiddlewareConsumer) {
    consumer.apply(HttpLoggerMiddleware).forRoutes('*');
  }
}
