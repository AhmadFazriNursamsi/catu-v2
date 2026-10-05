import {
  Injectable,
  CanActivate,
  ExecutionContext,
  ForbiddenException,
  UnauthorizedException,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { JwtService } from '@nestjs/jwt';
import { IS_PUBLIC_KEY } from '../decorators/public.decorator';
import { ALLOW_INACTIVE_KEY } from '../decorators/allow-inactive.decorator';
import { ACCOUNT_APPROVED, AccountStatusService } from '../access/account-status.service';

const INACTIVE_MESSAGES: Record<string, string> = {
  PENDING_APPROVAL: 'Akun Anda belum disetujui. Tunggu persetujuan sebelum menggunakan layanan ini.',
  REJECTED: 'Pendaftaran akun Anda ditolak. Layanan ini tidak dapat digunakan.',
};

@Injectable()
export class JwtAuthGuard implements CanActivate {
  constructor(
    private readonly jwtService: JwtService,
    private readonly reflector: Reflector,
    private readonly accounts: AccountStatusService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const targets = [context.getHandler(), context.getClass()];
    const isPublic = this.reflector.getAllAndOverride<boolean>(IS_PUBLIC_KEY, targets);
    if (isPublic) return true;

    const request = context.switchToHttp().getRequest();
    const authHeader = request.headers.authorization;

    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      throw new UnauthorizedException('Token otentikasi tidak ditemukan');
    }

    const token = authHeader.split(' ')[1];
    let payload: any;
    try {
      payload = await this.jwtService.verifyAsync(token);
    } catch {
      throw new UnauthorizedException('Token otentikasi tidak valid atau sudah kadaluarsa');
    }

    // Status dan peran diambil dari database, bukan dari token: akun yang belum disetujui/ditolak/nonaktif
    // tidak boleh memakai API, dan perubahan peran berlaku seketika.
    const account = await this.accounts.get(Number(payload.sub));
    if (!account) throw new UnauthorizedException('Akun tidak ditemukan');
    if (!account.isActive) throw new ForbiddenException('Akun Anda dinonaktifkan');
    if (account.status !== ACCOUNT_APPROVED) {
      const allowed = this.reflector.getAllAndOverride<boolean>(ALLOW_INACTIVE_KEY, targets);
      if (!allowed) throw new ForbiddenException(INACTIVE_MESSAGES[account.status] ?? 'Akun Anda belum aktif');
    }
    request.user = { ...payload, roleCode: account.roleCode };
    return true;
  }
}
