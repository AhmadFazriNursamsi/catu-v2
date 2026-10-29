import { Body, Controller, Get, Header, HttpCode, Post, Query } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';
import { IsNotEmpty, IsString, MaxLength } from 'class-validator';
import { Public } from '../../common/decorators/public.decorator';
import { LoginLinkService } from './login-link.service';
import { renderLoginLinkPage } from './login-link.page';

const STRICT_LIMIT = { default: { limit: 10, ttl: 60000 } };

class LoginLinkDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(128)
  token!: string;
}

@ApiTags('Auth')
@Controller('auth')
export class LoginLinkController {
  constructor(private readonly links: LoginLinkService) {}

  @Public()
  @Throttle(STRICT_LIMIT)
  @Post('login-link')
  @HttpCode(200)
  @ApiOperation({ summary: 'Tukar tautan masuk sekali pakai (WhatsApp) dengan sesi' })
  login(@Body() dto: LoginLinkDto) {
    return this.links.consume(dto.token);
  }
}

@ApiTags('Public')
@Controller('public/m')
export class LoginLinkPageController {
  @Public()
  @Throttle(STRICT_LIMIT)
  @Get('login')
  @Header('Content-Type', 'text/html; charset=utf-8')
  @Header('Cache-Control', 'no-store')
  @Header('Referrer-Policy', 'no-referrer')
  @ApiOperation({ summary: 'Halaman cadangan tautan masuk (tidak menukar token)' })
  page(@Query('t') token?: string) {
    return renderLoginLinkPage(token);
  }
}
