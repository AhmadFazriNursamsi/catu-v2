import { Module } from '@nestjs/common';
import { AuthController } from './auth.controller';
import { ApprovalsController } from './approvals.controller';
import { ApprovalPolicyService } from './approval-policy.service';
import { AuthService } from './auth.service';
import { PasswordService } from './password.service';
import { FcmModule } from '../fcm/fcm.module';

@Module({
  imports: [FcmModule],
  controllers: [AuthController, ApprovalsController],
  providers: [AuthService, PasswordService, ApprovalPolicyService],
  exports: [AuthService, PasswordService],
})
export class AuthModule {}
