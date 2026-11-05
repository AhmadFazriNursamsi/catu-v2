import 'reflect-metadata';

// @nestjs/config hanya ESM; tes ini membaca metadata dekorator saja, jadi cukup stub impornya.
jest.mock('@nestjs/config', () => ({ ConfigService: class {}, ConfigModule: class {} }));

import { GUARDS_METADATA } from '@nestjs/common/constants';
import { ApkController } from './apk.controller';
import { ApkUploadTokenGuard } from './apk-upload-token.guard';

describe('endpoint unggah APK untuk CI', () => {
  it.each(['getUploadUrlForCi', 'uploadLocalApkForCi'])('%s dijaga ApkUploadTokenGuard', (name) => {
    const guards = Reflect.getMetadata(GUARDS_METADATA, (ApkController.prototype as any)[name]) ?? [];
    expect(guards).toContain(ApkUploadTokenGuard);
  });
});
