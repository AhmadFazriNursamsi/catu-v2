import { Module } from '@nestjs/common';
import { OrdersController } from './orders.controller';
import { OrdersService } from './orders.service';
import { OrderReviewsService } from './order-reviews.service';
import { RomoCancelService } from './romo-cancel.service';
import { FcmModule } from '../fcm/fcm.module';

@Module({
  imports: [FcmModule],
  controllers: [OrdersController],
  providers: [OrdersService, OrderReviewsService, RomoCancelService],
  exports: [OrdersService, OrderReviewsService],
})
export class OrdersModule {}
