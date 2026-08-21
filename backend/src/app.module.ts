import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import {
  AuthController,
  OrdersController,
  AssignmentsController,
  ChatController,
  TestRunnerController,
  MasterDataController,
} from './app.controller';
import { AppService } from './app.service';

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
    }),
  ],
  controllers: [
    AuthController,
    OrdersController,
    AssignmentsController,
    ChatController,
    TestRunnerController,
    MasterDataController,
  ],
  providers: [AppService],
})
export class AppModule {}
