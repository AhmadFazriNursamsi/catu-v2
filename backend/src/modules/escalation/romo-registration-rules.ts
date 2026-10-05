import { randomInt } from 'crypto';

const PASSWORD_ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789'; // tanpa huruf/angka yang mirip (0 O 1 l I)

/** Kata sandi sementara yang mudah dibaca dan dibagikan; ditampilkan sekali kepada Koordinator. */
export function generatePassword(length = 10): string {
  return Array.from({ length }, () => PASSWORD_ALPHABET[randomInt(PASSWORD_ALPHABET.length)]).join('');
}

/** "0812-3456-7890" / "+62 812..." / "812..." -> "628123456789"; null bila bukan nomor yang masuk akal. */
export function normalizePhone(raw: string): string | null {
  let digits = String(raw ?? '').replace(/\D/g, '');
  if (digits.startsWith('0')) digits = `62${digits.slice(1)}`;
  else if (digits.startsWith('8')) digits = `62${digits}`;
  return /^62\d{8,13}$/.test(digits) ? digits : null;
}
