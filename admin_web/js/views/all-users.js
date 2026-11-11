// ── Semua User Aktif (khusus Super Admin) ──
// Satu daftar untuk seluruh akun berstatus APPROVED dan aktif, lintas peran, dengan pencarian & filter peran.

const ALL_USERS_ROLE_LABELS = {
  UMAT: 'Umat Katolik',
  UMAT_PENDATANG: 'Umat Pendatang',
  PENGURUS_LINGKUNGAN: 'Pengurus Lingkungan',
  KOORDINATOR: 'Koordinator Keuskupan',
  ROMO_PAROKI: 'Romo Paroki',
  ROMO_ORDO: 'Romo Ordo',
  ADMIN: 'Admin',
  SUPERADMIN: 'Super Admin',
};

const ALL_USERS_ROLE_STYLE = {
  UMAT: 'bg-blue-50 text-blue-800 border-blue-200',
  UMAT_PENDATANG: 'bg-sky-50 text-sky-800 border-sky-200',
  PENGURUS_LINGKUNGAN: 'bg-amber-50 text-amber-800 border-amber-200',
  KOORDINATOR: 'bg-orange-50 text-orange-800 border-orange-200',
  ROMO_PAROKI: 'bg-violet-50 text-violet-800 border-violet-200',
  ROMO_ORDO: 'bg-purple-50 text-purple-800 border-purple-200',
  ADMIN: 'bg-slate-100 text-slate-700 border-slate-300',
  SUPERADMIN: 'bg-indigo-100 text-indigo-700 border-indigo-200',
};

// Kategori sama dengan menu per peran: pengurus & koordinator dipisah dari umat biasa.
function allUsersCategory(u) {
  if (typeof isKoordinatorUser === 'function' && isKoordinatorUser(u)) return 'KOORDINATOR';
  if (typeof isPurePengurusUser === 'function' && isPurePengurusUser(u)) return 'PENGURUS_LINGKUNGAN';
  return (u.role_code || u.roleCode || '').toUpperCase();
}

function isActiveAccount(u) {
  const status = (u.account_status || u.accountStatus || '').toUpperCase();
  const active = u.is_active ?? u.isActive;
  return status === 'APPROVED' && active !== false;
}

// Asal/wilayah pelayanan ringkas sesuai peran.
function allUsersArea(u) {
  const cat = allUsersCategory(u);
  if (cat === 'ROMO_ORDO') return u.ordo_name || u.keuskupan_name || '-';
  if (cat === 'UMAT_PENDATANG') return [u.kota_name, u.provinsi_name].filter(Boolean).join(', ') || '-';
  if (cat === 'KOORDINATOR') return u.keuskupan_name || '-';
  if (cat === 'ADMIN' || cat === 'SUPERADMIN') return 'Portal Admin';
  return [u.paroki_name, u.lingkungan_name].filter(Boolean).join(' · ') || u.keuskupan_name || '-';
}

function allUsersJoined(u) {
  const raw = u.created_at || u.createdAt;
  if (!raw) return '-';
  const d = new Date(raw);
  return isNaN(d) ? '-' : d.toLocaleDateString('id-ID', { day: '2-digit', month: 'short', year: 'numeric' });
}

function renderAllUsersTab() {
  const q = (state.allUsersSearch || '').toLowerCase().trim();
  const roleFilter = state.allUsersRole || '';
  const active = (state.users || []).filter(isActiveAccount);
  const counts = {};
  active.forEach(u => { const c = allUsersCategory(u); counts[c] = (counts[c] || 0) + 1; });

  const rows = active.filter(u => {
    if (roleFilter && allUsersCategory(u) !== roleFilter) return false;
    if (!q) return true;
    return [u.full_name, u.fullName, u.email, u.phone_number, u.phoneNumber, allUsersArea(u), ALL_USERS_ROLE_LABELS[allUsersCategory(u)]]
      .some(v => (v || '').toLowerCase().includes(q));
  }).sort((a, b) => (a.full_name || a.fullName || '').localeCompare(b.full_name || b.fullName || '', 'id'));

  const chip = (code, label, n) => `
    <button onclick="state.allUsersRole = '${code}'; renderApp();"
      class="px-3 py-1.5 rounded-full text-[11px] font-bold border transition ${roleFilter === code ? 'bg-blue-950 text-white border-blue-950' : 'bg-white text-slate-700 border-slate-200 hover:bg-slate-50'}">
      ${escapeHtml(label)} <span class="ml-1 ${roleFilter === code ? 'text-blue-200' : 'text-slate-400'}">${n}</span>
    </button>`;

  return `
    <div class="space-y-6 animate-fade-in">
      <div class="bg-white rounded-2xl border border-slate-200/90 shadow-sm overflow-hidden">
        <div class="p-4 sm:p-6 border-b border-slate-200/80 bg-slate-50/50 space-y-3">
          <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
            <div class="relative w-full max-w-md">
              <i data-lucide="search" class="w-4 h-4 absolute left-3.5 top-1/2 -translate-y-1/2 text-slate-400"></i>
              <input type="text" id="allUsersSearchInput" placeholder="Cari nama, email, no. WhatsApp, paroki, peran..." value="${escapeHtml(state.allUsersSearch || '')}"
                oninput="state.allUsersSearch = this.value; renderApp();"
                class="w-full pl-10 pr-4 py-2.5 bg-white border border-slate-200 rounded-xl text-xs font-bold text-slate-900 focus:outline-none focus:ring-2 focus:ring-slate-400 shadow-sm transition" />
            </div>
            <p class="text-xs font-bold text-slate-500">${rows.length} dari ${active.length} user aktif</p>
          </div>
          <div class="flex flex-wrap gap-2">
            ${chip('', 'Semua', active.length)}
            ${Object.keys(ALL_USERS_ROLE_LABELS).filter(c => counts[c]).map(c => chip(c, ALL_USERS_ROLE_LABELS[c], counts[c])).join('')}
          </div>
        </div>
        <div class="overflow-x-auto">
          <table class="w-full min-w-[820px] text-left text-xs">
            <thead class="bg-slate-50 text-slate-600 font-bold border-b border-slate-200 tracking-wider uppercase text-[10.5px]">
              <tr>
                <th class="px-6 py-4">NAMA LENGKAP</th>
                <th class="px-6 py-4">PERAN</th>
                <th class="px-6 py-4">NO. WHATSAPP</th>
                <th class="px-6 py-4">PAROKI / WILAYAH</th>
                <th class="px-6 py-4">TERDAFTAR</th>
                <th class="px-6 py-4 text-right">AKSI</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-slate-100 font-medium text-slate-700">
              ${rows.length === 0 ? `
                <tr><td colspan="6" class="text-center py-16 text-slate-400">
                  <p class="font-bold text-slate-700 text-sm">Tidak ada user aktif yang sesuai filter</p>
                </td></tr>
              ` : rows.map(u => {
                const cat = allUsersCategory(u);
                return `
                <tr onclick="viewUserProfileModal('${u.id}')" class="hover:bg-slate-50/80 transition duration-150 cursor-pointer group">
                  <td class="px-6 py-4">
                    <p class="font-bold text-slate-900 text-sm tracking-tight group-hover:text-blue-900 transition">${escapeHtml(u.full_name || u.fullName || '-')}</p>
                    <p class="text-[11px] text-slate-400 font-medium truncate max-w-xs mt-0.5">${escapeHtml(u.email || '-')}</p>
                  </td>
                  <td class="px-6 py-4">
                    <span class="px-2.5 py-0.5 rounded-full border font-bold text-[10.5px] whitespace-nowrap ${ALL_USERS_ROLE_STYLE[cat] || 'bg-slate-100 text-slate-700 border-slate-300'}">${escapeHtml(ALL_USERS_ROLE_LABELS[cat] || cat || '-')}</span>
                  </td>
                  <td class="px-6 py-4 font-semibold text-slate-700 whitespace-nowrap">${escapeHtml(u.phone_number || u.phoneNumber || '-')}</td>
                  <td class="px-6 py-4 text-xs"><span class="truncate block max-w-[240px]">${escapeHtml(allUsersArea(u))}</span></td>
                  <td class="px-6 py-4 text-xs whitespace-nowrap">${escapeHtml(allUsersJoined(u))}</td>
                  <td class="px-6 py-4 text-right">
                    <button onclick="event.stopPropagation(); viewUserProfileModal('${u.id}')"
                      class="inline-flex items-center space-x-1 text-xs font-semibold text-blue-700 hover:text-blue-900 transition py-1 px-1.5 rounded hover:bg-blue-50">
                      <i data-lucide="eye" class="w-3.5 h-3.5 text-blue-600"></i><span>Detail</span>
                    </button>
                  </td>
                </tr>`;
              }).join('')}
            </tbody>
          </table>
        </div>
      </div>
    </div>`;
}
