import { createWriteStream, existsSync, mkdirSync, statSync } from 'node:fs';
import { dirname } from 'node:path';
import {
  Controller,
  Get,
  Header,
  HttpStatus,
  Put,
  Req,
  Res,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiResponse, ApiTags } from '@nestjs/swagger';
import type { Request, Response } from 'express';
import { ApkService } from './apk.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';

@ApiTags('Public Downloads')
@Controller('public')
export class ApkController {
  constructor(private readonly apkService: ApkService) {}

  @Get('apk')
  @Header('Cache-Control', 'no-store')
  @Header('X-Content-Type-Options', 'nosniff')
  @ApiOperation({ summary: 'Redirect atau unduh APK CATU terbaru' })
  @ApiResponse({ status: 302, description: 'Redirect ke signed URL APK di object storage' })
  @ApiResponse({ status: 200, description: 'Download APK langsung dari server lokal' })
  @ApiResponse({ status: 503, description: 'Konfigurasi APK atau object storage belum tersedia' })
  async redirectToApk(@Res() response: Response): Promise<void> {
    const localApkPath = process.env.LOCAL_APK_PATH || '/app/public/CATU.apk';
    if (existsSync(localApkPath)) {
      response.download(localApkPath, 'CATU.apk');
      return;
    }
    const signedUrl = await this.apkService.createDownloadUrl();
    response.redirect(HttpStatus.FOUND, signedUrl);
  }

  @Get('apk/upload-url')
  @ApiBearerAuth('JWT-auth')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('SUPERADMIN', 'ADMIN')
  @ApiOperation({ summary: 'Dapatkan presigned S3 URL untuk upload APK CATU terbaru' })
  @ApiResponse({ status: 200, description: 'Presigned upload URL' })
  async getUploadUrl(): Promise<{ uploadUrl: string }> {
    const uploadUrl = await this.apkService.createUploadUrl();
    return { uploadUrl };
  }

  @Put('apk/local')
  @ApiBearerAuth('JWT-auth')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('SUPERADMIN', 'ADMIN')
  @ApiOperation({ summary: 'Upload file binary APK CATU langsung ke server disk' })
  @ApiResponse({ status: 200, description: 'APK berhasil disimpan di server' })
  async uploadLocalApk(@Req() req: Request): Promise<{ message: string; size: number }> {
    const localApkPath = process.env.LOCAL_APK_PATH || '/app/public/CATU.apk';
    const dir = dirname(localApkPath);
    if (!existsSync(dir)) {
      mkdirSync(dir, { recursive: true });
    }

    const writeStream = createWriteStream(localApkPath);
    await new Promise<void>((resolve, reject) => {
      req.pipe(writeStream);
      writeStream.on('finish', resolve);
      writeStream.on('error', reject);
      req.on('error', reject);
    });

    const stats = statSync(localApkPath);
    return {
      message: 'APK berhasil diunggah ke server lokal',
      size: stats.size,
    };
  }
}

