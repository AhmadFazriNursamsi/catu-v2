import { Module } from '@nestjs/common';
import { OtpService } from './otp.service';
import { PasswordResetService } from './password-reset.service';

@Module({
  providers: [OtpService, PasswordResetService],
  exports: [OtpService, PasswordResetService],
})
export class OtpModule {}
