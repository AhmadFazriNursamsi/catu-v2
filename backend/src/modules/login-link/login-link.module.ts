import { Module } from '@nestjs/common';
import { LoginLinkController, LoginLinkPageController } from './login-link.controller';
import { LoginLinkService } from './login-link.service';

@Module({
  controllers: [LoginLinkController, LoginLinkPageController],
  providers: [LoginLinkService],
  exports: [LoginLinkService],
})
export class LoginLinkModule {}
