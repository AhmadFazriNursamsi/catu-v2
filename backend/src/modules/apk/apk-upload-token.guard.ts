import { CanActivate, ExecutionContext, ForbiddenException, Injectable, UnauthorizedException } from '@nestjs/common';
import type { Request } from 'express';
import { MIN_UPLOAD_TOKEN_LENGTH, uploadTokenMatches } from './apk-upload-token';

export const APK_UPLOAD_TOKEN_HEADER = 'x-apk-upload-token';

/** Mengizinkan permintaan hanya bila header X-Apk-Upload-Token sama dengan APK_UPLOAD_TOKEN di server. */
@Injectable()
export class ApkUploadTokenGuard implements CanActivate {
  canActivate(context: ExecutionContext): boolean {
    const configured = process.env.APK_UPLOAD_TOKEN;
    if (!configured || configured.length < MIN_UPLOAD_TOKEN_LENGTH) {
      throw new ForbiddenException('Unggah APK lewat token dinonaktifkan (APK_UPLOAD_TOKEN belum diatur di server).');
    }
    const req = context.switchToHttp().getRequest<Request>();
    if (!uploadTokenMatches(req.headers[APK_UPLOAD_TOKEN_HEADER], configured)) {
      throw new UnauthorizedException('Token unggah APK tidak valid.');
    }
    return true;
  }
}
