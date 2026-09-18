import { Global, Module } from '@nestjs/common';
import { DrizzleService } from './drizzle.service';

export const DRIZZLE_DB = 'DRIZZLE_DB';

@Global()
@Module({
  providers: [
    DrizzleService,
    {
      provide: DRIZZLE_DB,
      useFactory: (drizzleService: DrizzleService) => drizzleService.db,
      inject: [DrizzleService],
    },
  ],
  exports: [DrizzleService, DRIZZLE_DB],
})
export class DrizzleModule {}
