function escapeSettingsHtml(value) {
  const entities = {
    '&': '&amp;',
    '<': '&lt;',
    '>': '&gt;',
    '"': '&quot;',
    "'": '&#39;',
  };

  return String(value).replace(/[&<>"']/g, (character) => entities[character]);
}

function renderSettingsTab() {
  const hasDownloadUrl = Boolean(APK_DOWNLOAD_URL);
  const safeDownloadUrl = hasDownloadUrl ? escapeSettingsHtml(APK_DOWNLOAD_URL) : '';

  return `
    <div class="max-w-5xl space-y-6">
      <div>
        <p class="text-xs font-bold uppercase tracking-[0.18em] text-amber-600">Konfigurasi Portal</p>
        <h2 class="mt-1 text-2xl font-extrabold tracking-tight text-slate-900">Pengaturan Aplikasi</h2>
        <p class="mt-2 max-w-2xl text-sm font-medium leading-relaxed text-slate-500">
          Kelola distribusi aplikasi Android CATU. QR code di bawah mengarah ke URL download publik yang sudah dikonfigurasi.
        </p>
      </div>

      <section class="overflow-hidden rounded-3xl border border-slate-200 bg-white shadow-sm">
        <div class="border-b border-slate-100 bg-gradient-to-r from-blue-950 to-blue-900 px-6 py-5 text-white lg:px-8">
          <div class="flex items-start gap-4">
            <div class="flex h-11 w-11 flex-shrink-0 items-center justify-center rounded-2xl bg-amber-400 text-blue-950 shadow-lg shadow-blue-950/20">
              <i data-lucide="smartphone" class="h-5 w-5"></i>
            </div>
            <div>
              <h3 class="text-base font-extrabold">Distribusi Aplikasi Android</h3>
              <p class="mt-1 text-xs font-medium leading-relaxed text-blue-100">
                Bagikan QR ini untuk mengunduh APK CATU dari perangkat mobile.
              </p>
            </div>
          </div>
        </div>

        <div class="grid gap-8 p-6 lg:grid-cols-[minmax(0,1fr)_280px] lg:p-8">
          <div class="flex min-w-0 flex-col justify-center">
            <p class="text-[11px] font-extrabold uppercase tracking-[0.16em] text-slate-400">URL Download Publik</p>
            ${hasDownloadUrl ? `
              <code class="mt-3 block break-all rounded-2xl border border-slate-200 bg-slate-50 px-4 py-3 text-xs font-bold leading-relaxed text-slate-700">${safeDownloadUrl}</code>
              <p class="mt-3 text-xs font-medium leading-relaxed text-slate-500">
                URL ini stabil untuk QR. Backend akan meneruskan request ke object storage dengan signed URL yang berlaku sementara.
              </p>
              <a id="apkDownloadLink" href="${safeDownloadUrl}" download="CATU.apk" target="_blank" rel="noopener" class="mt-6 inline-flex w-fit items-center gap-2 rounded-xl bg-amber-500 px-4 py-3 text-xs font-extrabold text-blue-950 shadow-lg shadow-amber-500/20 transition hover:bg-amber-400">
                <i data-lucide="download" class="h-4 w-4"></i>
                Download APK
              </a>
            ` : `
              <div class="mt-3 rounded-2xl border border-amber-200 bg-amber-50 px-4 py-3 text-xs font-bold leading-relaxed text-amber-800">
                URL APK belum dikonfigurasi. Isi <code>PUBLIC_APK_URL</code> lalu restart Admin Web.
              </div>
            `}
          </div>

          <div class="flex flex-col items-center justify-center rounded-3xl border border-slate-200 bg-slate-50 p-5 text-center">
            <div id="apkQrCode" class="flex h-[272px] w-[272px] items-center justify-center overflow-hidden rounded-2xl bg-white p-4 shadow-inner">
              <span class="text-xs font-semibold text-slate-400">Menyiapkan QR code...</span>
            </div>
            <p id="apkQrStatus" class="mt-4 text-xs font-semibold leading-relaxed text-slate-500">Memuat QR code...</p>
          </div>
        </div>
      </section>
    </div>
  `;
}

function initializeSettingsView() {
  const qrContainer = document.getElementById('apkQrCode');
  const status = document.getElementById('apkQrStatus');
  if (!qrContainer || !status) return;

  if (!APK_DOWNLOAD_URL) {
    qrContainer.innerHTML = '<span class="text-xs font-semibold text-amber-600">URL belum tersedia</span>';
    status.textContent = 'Konfigurasi URL APK belum tersedia.';
    return;
  }

  if (typeof QRCode === 'undefined') {
    qrContainer.innerHTML = '<span class="px-3 text-xs font-semibold text-rose-600">Library QR gagal dimuat</span>';
    status.textContent = 'Muat ulang halaman untuk mencoba lagi.';
    return;
  }

  qrContainer.innerHTML = '';
  new QRCode(qrContainer, {
    text: APK_DOWNLOAD_URL,
    width: 240,
    height: 240,
    colorDark: '#0f172a',
    colorLight: '#ffffff',
    correctLevel: QRCode.CorrectLevel.M,
  });
  status.textContent = 'Scan QR dengan kamera HP untuk mengunduh APK.';
}
