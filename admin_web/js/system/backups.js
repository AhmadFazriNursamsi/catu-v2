// ── Tab: Cadangan Data (Super Admin) — juga dapat dibuka langsung lewat /catubackup ──
// Data dari GET /backups/status: ringkasan tanpa rahasia yang ditulis scripts/server/backup.sh di server.

const BACKUP_PATH = '/catubackup';

function isBackupPath() {
  return window.location.pathname.replace(/\/+$/, '').endsWith(BACKUP_PATH);
}

/** Selaraskan alamat browser dengan tab: /catubackup untuk tab Cadangan, kembali ke / untuk tab lain. */
function syncBackupPath(tab) {
  const base = window.location.pathname.startsWith('/dev/') ? '/dev' : '';
  if (tab === 'backups' && !isBackupPath()) history.replaceState(null, '', `${base}${BACKUP_PATH}`);
  if (tab !== 'backups' && isBackupPath()) history.replaceState(null, '', `${base}/`);
}

async function loadBackupStatus() {
  state.backupLoading = true;
  renderApp();
  try {
    const res = await fetch(`${API_BASE}/backups/status`, { headers: { Authorization: `Bearer ${state.token}` } });
    state.backupStatus = res.ok ? await res.json() : { available: false, health: 'unknown', message: `Gagal memuat status cadangan (HTTP ${res.status}).` };
  } catch (_) {
    state.backupStatus = { available: false, health: 'unknown', message: 'Server tidak dapat dihubungi.' };
  }
  state.backupLoading = false;
  renderApp();
}

function fmtBytes(n) {
  if (n == null) return '-';
  if (n < 1024) return `${n} B`;
  if (n < 1024 * 1024) return `${(n / 1024).toFixed(0)} KB`;
  return `${(n / 1024 / 1024).toFixed(1)} MB`;
}

function fmtWib(iso) {
  if (!iso) return '-';
  const d = new Date(iso);
  if (isNaN(d.getTime())) return '-';
  return d.toLocaleString('id-ID', { timeZone: 'Asia/Jakarta', weekday: 'short', day: '2-digit', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' }) + ' WIB';
}

function cloudBadge(cloud, enabled) {
  if (cloud === 'ok') return '<span class="px-2 py-0.5 rounded-full text-[11px] font-bold bg-emerald-100 text-emerald-700">Tersalin ke S3</span>';
  if (cloud === 'failed') return '<span class="px-2 py-0.5 rounded-full text-[11px] font-bold bg-rose-100 text-rose-700">Gagal unggah</span>';
  if (!enabled || cloud === 'skipped') return '<span class="px-2 py-0.5 rounded-full text-[11px] font-bold bg-slate-100 text-slate-500">Hanya di server</span>';
  return '<span class="px-2 py-0.5 rounded-full text-[11px] font-bold bg-slate-100 text-slate-500">-</span>';
}

function renderBackupsTab() {
  const s = state.backupStatus;
  if (!s && !state.backupLoading) setTimeout(loadBackupStatus, 0); // mis. baru login lewat /catubackup
  if (!s || state.backupLoading) {
    return '<div class="p-12 text-center text-slate-500 text-sm">Memuat status cadangan…</div>';
  }
  if (!s.available) {
    return `<div class="p-8 bg-white rounded-2xl border border-slate-200 text-center space-y-3 max-w-xl mx-auto">
      <p class="text-sm font-bold text-slate-800">Status cadangan belum tersedia</p>
      <p class="text-xs text-slate-500">${escapeHtml(s.message || '')}</p>
      <button onclick="loadBackupStatus()" class="px-4 py-2 bg-blue-950 text-white rounded-xl text-xs font-bold">Muat ulang</button>
    </div>`;
  }
  // Kelas Tailwind ditulis utuh (bukan dirakit) agar ikut tersusun saat build CSS.
  const tone = {
    ok: { box: 'bg-emerald-50 border-emerald-200', icon: 'text-emerald-600', text: 'text-emerald-900', item: 'text-emerald-800', lucide: 'shield-check', title: 'Cadangan aman' },
    warning: { box: 'bg-amber-50 border-amber-200', icon: 'text-amber-600', text: 'text-amber-900', item: 'text-amber-800', lucide: 'shield-alert', title: 'Perlu perhatian' },
    error: { box: 'bg-rose-50 border-rose-200', icon: 'text-rose-600', text: 'text-rose-900', item: 'text-rose-800', lucide: 'shield-x', title: 'Cadangan bermasalah' },
  }[s.health] || { box: 'bg-slate-50 border-slate-200', icon: 'text-slate-600', text: 'text-slate-900', item: 'text-slate-700', lucide: 'shield', title: 'Tidak diketahui' };
  const latest = (s.daily || [])[0];
  const rows = (s.daily || []).map((d) => `
    <tr class="border-t border-slate-100">
      <td class="py-3 px-4 text-xs font-semibold text-slate-800">${escapeHtml(fmtWib(d.createdAt))}</td>
      <td class="py-3 px-4 text-xs text-slate-600">${fmtBytes(d.bytes)}</td>
      <td class="py-3 px-4 text-xs text-slate-600">${d.tables ?? '-'}</td>
      <td class="py-3 px-4">${cloudBadge(d.cloud, s.cloudEnabled)}</td>
    </tr>`).join('');
  const deployRows = (s.deploy || []).map((d) => `
    <li class="flex justify-between text-xs py-1.5 border-t border-slate-100"><span class="text-slate-700">${escapeHtml(fmtWib(d.createdAt))}</span><span class="text-slate-500">${fmtBytes(d.bytes)}</span></li>`).join('');
  const problems = (s.problems || []).map((p) => `<li class="text-xs ${tone.item}">• ${escapeHtml(p)}</li>`).join('');
  return `
    <div class="space-y-4">
      <div class="p-5 rounded-2xl border ${tone.box} flex items-start gap-3">
        <i data-lucide="${tone.lucide}" class="w-6 h-6 ${tone.icon} shrink-0"></i>
        <div class="flex-1 space-y-1">
          <p class="text-sm font-extrabold ${tone.text}">${tone.title}</p>
          <p class="text-xs text-slate-600">Cadangan terakhir: <b>${escapeHtml(fmtWib(latest?.createdAt))}</b>${s.latestAgeHours != null ? ` (${s.latestAgeHours} jam lalu)` : ''}</p>
          ${problems ? `<ul class="pt-1 space-y-0.5">${problems}</ul>` : ''}
        </div>
        <button onclick="loadBackupStatus()" class="px-3 py-1.5 bg-white border border-slate-200 rounded-lg text-xs font-bold text-slate-700">Muat ulang</button>
      </div>
      <div class="grid grid-cols-1 sm:grid-cols-3 gap-3">
        <div class="p-4 bg-white rounded-2xl border border-slate-200"><p class="text-[11px] text-slate-500">Cadangan harian</p><p class="text-lg font-extrabold text-slate-900">${(s.daily || []).length} <span class="text-xs font-medium text-slate-500">/ maks ${s.keepDaily}</span></p></div>
        <div class="p-4 bg-white rounded-2xl border border-slate-200"><p class="text-[11px] text-slate-500">Salinan cloud (S3)</p><p class="text-lg font-extrabold ${s.cloudEnabled ? 'text-emerald-700' : 'text-slate-500'}">${s.cloudEnabled ? 'Aktif' : 'Belum aktif'}</p></div>
        <div class="p-4 bg-white rounded-2xl border border-slate-200"><p class="text-[11px] text-slate-500">Disk server</p><p class="text-lg font-extrabold text-slate-900">${s.disk?.usedPct ?? '-'}% <span class="text-xs font-medium text-slate-500">terpakai, sisa ${s.disk?.freeMb != null ? (s.disk.freeMb / 1024).toFixed(0) + ' GB' : '-'}</span></p></div>
      </div>
      <div class="bg-white rounded-2xl border border-slate-200 overflow-x-auto">
        <p class="px-4 pt-4 text-sm font-extrabold text-slate-900">Cadangan harian (otomatis tiap 02.15 WIB)</p>
        <table class="w-full mt-2"><thead><tr class="text-left text-[11px] text-slate-500">
          <th class="py-2 px-4">Waktu</th><th class="py-2 px-4">Ukuran</th><th class="py-2 px-4">Tabel</th><th class="py-2 px-4">Cloud</th>
        </tr></thead><tbody>${rows || '<tr><td colspan="4" class="p-4 text-xs text-slate-500">Belum ada.</td></tr>'}</tbody></table>
      </div>
      ${renderCloudUploads(s)}
      <div class="bg-white rounded-2xl border border-slate-200 p-4">
        <p class="text-sm font-extrabold text-slate-900">Cadangan sebelum deploy</p>
        <ul class="mt-2">${deployRows || '<li class="text-xs text-slate-500">Belum ada.</li>'}</ul>
      </div>
      <p class="text-[11px] text-slate-400">Ringkasan diperbarui ${escapeHtml(fmtWib(s.generatedAt))}. Halaman ini hanya menampilkan status; isi cadangan tidak pernah dikirim ke browser.</p>
    </div>`;
}

/** Riwayat berkas yang berhasil diunggah ke S3 (tetap ada di cloud walau cadangan lokal 7 hari sudah dirotasi). */
function renderCloudUploads(s) {
  if (!s.cloudEnabled) return '';
  const list = s.cloudUploads || [];
  const rows = list.map((u) => `
    <tr class="border-t border-slate-100">
      <td class="py-3 px-4 text-xs font-semibold text-slate-800 whitespace-nowrap">${escapeHtml(fmtWib(u.createdAt))}</td>
      <td class="py-3 px-4 text-[11px] font-mono text-slate-600 break-all">${escapeHtml(u.key)}</td>
      <td class="py-3 px-4 text-xs text-slate-600 whitespace-nowrap">${fmtBytes(u.bytes)}</td>
      <td class="py-3 px-4 text-[11px] font-mono text-slate-500" title="${escapeHtml(u.sha256 || '')}">${u.sha256 ? escapeHtml(u.sha256.slice(0, 12)) + '…' : '-'}</td>
    </tr>`).join('');
  return `
      <div class="bg-white rounded-2xl border border-slate-200 overflow-x-auto">
        <div class="px-4 pt-4 flex flex-wrap items-baseline justify-between gap-2">
          <p class="text-sm font-extrabold text-slate-900">Riwayat di Cloud (S3) <span class="text-xs font-medium text-slate-500">· ${list.length} berkas</span></p>
          <p class="text-[11px] font-mono text-slate-500 break-all">${escapeHtml(s.cloudTarget || '')}</p>
        </div>
        <p class="px-4 text-[11px] text-slate-500">Berkas terenkripsi yang sudah berhasil diunggah. Tidak ikut terhapus saat cadangan lokal dirotasi.</p>
        <table class="w-full mt-2"><thead><tr class="text-left text-[11px] text-slate-500">
          <th class="py-2 px-4">Waktu</th><th class="py-2 px-4">Berkas di S3</th><th class="py-2 px-4">Ukuran</th><th class="py-2 px-4">SHA-256</th>
        </tr></thead><tbody>${rows || '<tr><td colspan="4" class="p-4 text-xs text-slate-500">Belum ada unggahan.</td></tr>'}</tbody></table>
      </div>`;
}
