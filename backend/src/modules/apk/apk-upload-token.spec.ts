import { ExecutionContext, ForbiddenException, UnauthorizedException } from '@nestjs/common';
import { uploadTokenMatches } from './apk-upload-token';
import { ApkUploadTokenGuard } from './apk-upload-token.guard';

const TOKEN = 'a'.repeat(40);

describe('uploadTokenMatches', () => {
  it('cocok hanya untuk token yang sama', () => {
    expect(uploadTokenMatches(TOKEN, TOKEN)).toBe(true);
    expect(uploadTokenMatches(TOKEN + 'x', TOKEN)).toBe(false);
    expect(uploadTokenMatches('salah', TOKEN)).toBe(false);
  });

  it('selalu gagal bila token server kosong atau terlalu pendek', () => {
    expect(uploadTokenMatches('', '')).toBe(false);
    expect(uploadTokenMatches('pendek', 'pendek')).toBe(false);
    expect(uploadTokenMatches(TOKEN, undefined)).toBe(false);
  });

  it('menolak header kosong, larik, atau bukan string', () => {
    expect(uploadTokenMatches(undefined, TOKEN)).toBe(false);
    expect(uploadTokenMatches([TOKEN], TOKEN)).toBe(false);
  });
});

describe('ApkUploadTokenGuard', () => {
  const ctx = (headers: Record<string, unknown>) =>
    ({ switchToHttp: () => ({ getRequest: () => ({ headers }) }) }) as unknown as ExecutionContext;
  const guard = new ApkUploadTokenGuard();
  const prev = process.env.APK_UPLOAD_TOKEN;
  afterEach(() => {
    if (prev === undefined) delete process.env.APK_UPLOAD_TOKEN;
    else process.env.APK_UPLOAD_TOKEN = prev;
  });

  it('403 bila fitur belum diatur di server', () => {
    delete process.env.APK_UPLOAD_TOKEN;
    expect(() => guard.canActivate(ctx({ 'x-apk-upload-token': TOKEN }))).toThrow(ForbiddenException);
  });

  it('401 untuk token salah atau tanpa header', () => {
    process.env.APK_UPLOAD_TOKEN = TOKEN;
    expect(() => guard.canActivate(ctx({ 'x-apk-upload-token': 'b'.repeat(40) }))).toThrow(UnauthorizedException);
    expect(() => guard.canActivate(ctx({}))).toThrow(UnauthorizedException);
  });

  it('lolos untuk token yang benar', () => {
    process.env.APK_UPLOAD_TOKEN = TOKEN;
    expect(guard.canActivate(ctx({ 'x-apk-upload-token': TOKEN }))).toBe(true);
  });
});

