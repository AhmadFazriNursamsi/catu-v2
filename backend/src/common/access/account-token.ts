import type { JwtService } from '@nestjs/jwt';

interface TokenSubject {
  id: number | string;
  uuid?: string;
  phoneNumber?: string;
  roleCode: string;
  fullName?: string;
}

/** Token akses untuk akun yang baru didaftarkan (sama kuasanya dengan login akun PENDING). */
export function signAccountToken(jwt: JwtService, u: TokenSubject): string {
  return jwt.sign({
    sub: u.id,
    uuid: u.uuid,
    phoneNumber: u.phoneNumber,
    roleCode: u.roleCode,
    fullName: u.fullName,
  });
}
