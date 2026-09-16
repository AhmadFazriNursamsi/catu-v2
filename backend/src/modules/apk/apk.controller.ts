import { Controller, Get, Header, HttpStatus, Res } from '@nestjs/common';
import { ApiOperation, ApiResponse, ApiTags } from '@nestjs/swagger';
import type { Response } from 'express';
import { ApkService } from './apk.service';

@ApiTags('Public Downloads')
@Controller('public')
export class ApkController {
  constructor(private readonly apkService: ApkService) {}

  @Get('apk')
  @Header('Cache-Control', 'no-store')
  @Header('X-Content-Type-Options', 'nosniff')
  @ApiOperation({ summary: 'Redirect ke download APK CATU terbaru' })
  @ApiResponse({ status: 302, description: 'Redirect ke signed URL APK di object storage' })
  @ApiResponse({ status: 503, description: 'Konfigurasi APK atau object storage belum tersedia' })
  async redirectToApk(@Res() response: Response): Promise<void> {
    const signedUrl = await this.apkService.createDownloadUrl();
    response.redirect(HttpStatus.FOUND, signedUrl);
  }
}
