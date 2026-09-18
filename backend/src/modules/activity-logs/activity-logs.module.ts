import { Global, Module } from '@nestjs/common';
import { APP_INTERCEPTOR } from '@nestjs/core';
import { ActivityLogsService } from './activity-logs.service';
import { ActivityLogsController } from './activity-logs.controller';
import { ActivityLogInterceptor } from './activity-logs.interceptor';

@Global()
@Module({
  controllers: [ActivityLogsController],
  providers: [
    ActivityLogsService,
    {
      provide: APP_INTERCEPTOR,
      useClass: ActivityLogInterceptor,
    },
  ],
  exports: [ActivityLogsService],
})
export class ActivityLogsModule {}
