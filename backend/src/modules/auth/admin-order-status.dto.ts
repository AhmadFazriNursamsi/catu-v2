import { IsIn } from 'class-validator';
import { SERVICE_STATUSES } from '../order-rules/order-status-machine';

export class AdminOrderStatusDto {
  @IsIn(SERVICE_STATUSES)
  status: string;
}
