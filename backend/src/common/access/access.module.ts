import { Global, Module } from '@nestjs/common';
import { AccessService } from './access.service';
import { AccountStatusService } from './account-status.service';

@Global()
@Module({
  providers: [AccessService, AccountStatusService],
  exports: [AccessService, AccountStatusService],
})
export class AccessModule {}
