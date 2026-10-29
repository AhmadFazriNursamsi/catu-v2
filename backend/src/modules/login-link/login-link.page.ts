import { LOGIN_LINK_TOKEN_PATTERN } from './login-link.service';

const APP_PACKAGE = 'com.example.catu_mobile';

/**
 * Halaman cadangan bila Android tidak langsung membuka aplikasi dari tautan (aplikasi belum terpasang atau
 * verifikasi App Links belum aktif). Halaman ini TIDAK menukar token: hanya mengarahkan ke aplikasi/unduhan,
 * sehingga pratinjau tautan WhatsApp tidak menghanguskan tautan.
 */
export function renderLoginLinkPage(token: string | undefined): string {
  const valid = typeof token === 'string' && LOGIN_LINK_TOKEN_PATTERN.test(token);
  const open = valid
    ? `<a class="btn" href="intent://m/login?t=${token}#Intent;scheme=catu;package=${APP_PACKAGE};end">Buka di aplikasi CATU</a>`
    : '<p class="warn">Tautan tidak lengkap. Minta Koordinator mengirim ulang, atau masuk dengan nomor HP dan kata sandi sementara dari WhatsApp.</p>';
  return `<!doctype html>
<html lang="id"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="robots" content="noindex,nofollow"><title>Masuk ke CATU</title>
<style>body{font-family:system-ui,sans-serif;background:#f8fafc;color:#0f172a;margin:0;padding:24px;display:flex;justify-content:center}
main{max-width:420px;width:100%;background:#fff;border:1px solid #e2e8f0;border-radius:20px;padding:28px 22px;text-align:center}
h1{font-size:20px;margin:0 0 8px}p{font-size:14px;color:#475569;line-height:1.5}
.btn{display:block;margin:14px 0;padding:14px;border-radius:14px;background:#0066ff;color:#fff;font-weight:700;text-decoration:none}
.alt{background:#fff;color:#0066ff;border:1.5px solid #0066ff}.warn{color:#b91c1c}</style></head>
<body><main><h1>Masuk ke CATU</h1>
<p>Ketuk tombol di bawah untuk masuk otomatis, lalu Anda diminta membuat kata sandi baru.</p>
${open}
<a class="btn alt" href="/api/public/apk">Unduh aplikasi CATU</a>
<p>Tautan berlaku sekali pakai. Jika sudah tidak berlaku, masuk dengan nomor HP dan kata sandi sementara dari WhatsApp.</p>
</main></body></html>`;
}
