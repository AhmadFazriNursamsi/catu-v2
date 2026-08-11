import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import {
  AuthController,
  OrdersController,
  AssignmentsController,
  ChatController,
  TestRunnerController,
} from './app.controller';
import { AppService } from './app.service';

@Module({
  imports: [
    TypeOrmModule.forRoot({
      type: 'postgres',
      host: process.env.DB_HOST || 'localhost',
      port: parseInt(process.env.DB_PORT || '5432', 10),
      username: process.env.DB_USERNAME || 'postgres',
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
  ],
  providers: [AppService],
})
export class AppModule {}
