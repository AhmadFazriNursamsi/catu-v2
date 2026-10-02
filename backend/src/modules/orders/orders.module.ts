import { Module } from '@nestjs/common';
import { OrdersController } from './orders.controller';
import { OrdersService } from './orders.service';
import { OrderReviewsService } from './order-reviews.service';
import { FcmModule } from '../fcm/fcm.module';

@Module({
  imports: [FcmModule],
  controllers: [OrdersController],
  providers: [OrdersService, OrderReviewsService],
  exports: [OrdersService, OrderReviewsService],
})
export class OrdersModule {}
