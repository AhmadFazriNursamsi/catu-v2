// ── Persetujuan Pendaftaran Akun: tampilan menyesuaikan jenis akun (Umat, Pengurus, Romo Paroki, Romo Ordo, Koordinator) ──

const APPROVAL_TABS = [
  { code: '', label: 'Semua', icon: 'layers' },
  { code: 'UMAT', label: 'Umat', icon: 'users' },
  { code: 'PENGURUS_LINGKUNGAN', label: 'Pengurus Lingkungan', icon: 'badge-check' },
  { code: 'ROMO_PAROKI', label: 'Romo Paroki', icon: 'church' },
  { code: 'ROMO_ORDO', label: 'Romo Ordo', icon: 'cross' },
  { code: 'KOORDINATOR', label: 'Koordinator', icon: 'award' },
];

const APPROVAL_KIND_STYLE = {
  UMAT: 'bg-blue-50 text-blue-900 border-blue-200',
  PENGURUS_LINGKUNGAN: 'bg-indigo-50 text-indigo-900 border-indigo-200',
  ROMO_PAROKI: 'bg-emerald-50 text-emerald-900 border-emerald-200',
  ROMO_ORDO: 'bg-purple-50 text-purple-900 border-purple-200',
  KOORDINATOR: 'bg-amber-50 text-amber-900 border-amber-300',
};

// Nama pendaftar dan data wilayah berasal dari pengguna: selalu di-escape sebelum masuk HTML.
function escapeApprovalHtml(value) {
  return escapeHtml(value);
}

function approvalKind(u) {
  const role = (u.role_code || u.roleCode || '').toUpperCase();
  const pos = (u.pengurus_position || u.pengurusPosition || '').toString().toLowerCase();
  if (pos.includes('koordinator') || role.includes('KOORDINATOR')) return 'KOORDINATOR';
  return APPROVAL_KIND_STYLE[role] ? role : 'UMAT';
}

function approvalIsLeader(u) {
  return /ketua|kepala|superior/i.test(u.romo_position || u.romoPosition || '');
}

function approvalRoleLabel(u) {
  const kind = approvalKind(u);
  if (kind === 'KOORDINATOR') return 'Koordinator Keuskupan';
  if (kind === 'ROMO_PAROKI') return approvalIsLeader(u) ? 'Kepala Romo Paroki' : 'Romo Paroki';
  if (kind === 'ROMO_ORDO') return approvalIsLeader(u) ? 'Ketua Romo Ordo' : 'Romo Ordo';
  if (kind === 'PENGURUS_LINGKUNGAN') return u.pengurus_position || u.pengurusPosition || 'Pengurus Lingkungan';
  return 'Umat';
}

function renderApprovalRoleBadge(u) {
  const kind = approvalKind(u);
  const icon = { UMAT: 'user', PENGURUS_LINGKUNGAN: 'badge-check', ROMO_PAROKI: 'church', ROMO_ORDO: 'cross', KOORDINATOR: 'award' }[kind];
  return `<span class="inline-flex items-center space-x-1.5 px-3 py-1.5 rounded-xl ${APPROVAL_KIND_STYLE[kind]} border font-bold text-xs shadow-2xs">
      <i data-lucide="${icon}" class="w-3.5 h-3.5"></i><span>${escapeApprovalHtml(approvalRoleLabel(u))}</span></span>`;
}

function approvalLine(text, strong) {
  if (!text) return '';
  return `<span class="${strong ? 'font-bold text-slate-900 text-xs' : 'text-[11px] text-slate-500'}">${escapeApprovalHtml(text)}</span>`;
}

// Judul kolom penugasan mengikuti jenis akun yang sedang ditampilkan.
function approvalAssignmentHeader(tab) {
  return { UMAT: 'LINGKUNGAN & PAROKI', PENGURUS_LINGKUNGAN: 'JABATAN & LINGKUNGAN', ROMO_PAROKI: 'PAROKI & POSISI', ROMO_ORDO: 'ORDO & POSISI', KOORDINATOR: 'KEUSKUPAN & KOTA' }[tab] || 'PENUGASAN & WILAYAH';
}

function renderApprovalAssignment(u) {
  const kind = approvalKind(u);
  const lines = [];
  if (kind === 'KOORDINATOR') {
    lines.push(approvalLine(u.keuskupan_name, true), approvalLine(u.kota_name));
  } else if (kind === 'ROMO_ORDO') {
    lines.push(approvalLine(u.ordo_name || 'Ordo belum dipilih', true), approvalLine(approvalIsLeader(u) ? 'Ketua / Superior' : 'Romo biasa'), approvalLine(u.kota_name));
  } else if (kind === 'ROMO_PAROKI') {
    lines.push(approvalLine(u.paroki_name || 'Paroki belum dipilih', true), approvalLine(approvalIsLeader(u) ? 'Kepala Romo Paroki' : 'Romo biasa'), approvalLine(u.keuskupan_name));
  } else if (kind === 'PENGURUS_LINGKUNGAN') {
    lines.push(approvalLine(u.pengurus_position || 'Jabatan belum dipilih', true), approvalLine(u.lingkungan_name && `Lkg. ${u.lingkungan_name}`), approvalLine(u.paroki_name));
  } else {
    lines.push(approvalLine(u.lingkungan_name ? `Lkg. ${u.lingkungan_name}` : 'Lingkungan belum dipilih', true), approvalLine(u.wilayah_name), approvalLine(u.paroki_name));
  }
  return `<div class="inline-flex flex-col">${lines.join('')}</div>`;
}

// Penyetuju yang ditunjuk; dipakai menentukan tombol aksi (umat dengan pengurus diverifikasi lewat aplikasi mobile).
function approvalApproverInfo(u) {
  const kind = approvalKind(u);
  if (kind === 'KOORDINATOR') return { text: 'Admin Aplikasi', hint: 'Hanya Admin', orphan: false };
  if (kind === 'ROMO_PAROKI' || kind === 'ROMO_ORDO') {
    if (approvalIsLeader(u)) return { text: 'Admin Aplikasi', hint: kind === 'ROMO_PAROKI' ? 'Kepala Romo disetujui Admin' : 'Ketua Ordo disetujui Admin', orphan: false };
    return { text: u.approver_name || 'Admin Aplikasi', hint: kind === 'ROMO_PAROKI' ? 'Kepala Romo Paroki' : 'Ketua Romo Ordo', orphan: false };
  }
  if (u.approver_name) return { text: u.approver_name, hint: kind === 'UMAT' ? 'Pengurus Lingkungan' : 'Ketua Lingkungan', orphan: false };
  return { text: 'Belum ada penyetuju', hint: 'Lingkungan tanpa pengurus — diproses Admin', orphan: true };
}

function renderApprovalActions(u) {
  const info = approvalApproverInfo(u);
  if (approvalKind(u) === 'UMAT' && !info.orphan) {
    return `<div class="inline-flex items-center space-x-1.5 px-3 py-1.5 rounded-xl bg-amber-50 text-amber-900 border border-amber-200/80 font-bold text-[11px] shadow-2xs" title="Persetujuan umat dilakukan oleh Pengurus Lingkungan lewat aplikasi mobile CATU">
        <i data-lucide="shield-alert" class="w-3.5 h-3.5 text-amber-600"></i><span>Verifikasi Pengurus Lingkungan</span></div>`;
  }
  const btn = (action, color, icon, label) => `<button onclick="event.stopPropagation(); approveUserAction('${Number(u.id)}', '${action}')"
        class="px-3.5 py-1.5 rounded-xl bg-${color}-600 hover:bg-${color}-700 text-white font-bold text-xs flex items-center space-x-1 transition shadow-md shadow-${color}-600/20 transform hover:-translate-y-0.5 cursor-pointer">
        <i data-lucide="${icon}" class="w-3.5 h-3.5"></i><span>${label}</span></button>`;
  const note = info.orphan ? `<p class="mt-1.5 text-[10.5px] font-semibold text-amber-700 text-right">Lingkungan tanpa pengurus — diproses Admin</p>` : '';
  return `<div class="inline-flex flex-col items-end"><div class="inline-flex items-center justify-end space-x-2">${btn('APPROVED', 'emerald', 'check', 'Setujui')}${btn('REJECTED', 'rose', 'x', 'Tolak')}</div>${note}</div>`;
}

function renderApprovalTabs(pendings) {
  const counts = {};
  for (const u of pendings) counts[approvalKind(u)] = (counts[approvalKind(u)] || 0) + 1;
  return `<div class="flex flex-wrap gap-1.5 sm:gap-2 p-3 sm:px-6 border-b border-slate-200/80 bg-white">${APPROVAL_TABS.map((t) => {
    const active = (state.approvalsFilterRole || '') === t.code;
    const n = t.code ? counts[t.code] || 0 : pendings.length;
    return `<button type="button" onclick="state.approvalsFilterRole = '${t.code}'; renderApp();"
      class="flex items-center space-x-2 px-3 sm:px-4 py-2 rounded-xl font-bold text-xs transition-all ${active ? 'bg-blue-950 text-white shadow-xs' : 'text-slate-600 hover:bg-slate-100 hover:text-blue-950'}">
      <i data-lucide="${t.icon}" class="w-4 h-4 ${active ? 'text-blue-400' : 'text-slate-400'}"></i><span>${t.label}</span>
      <span class="px-1.5 py-0.5 rounded-full text-[10px] ${active ? 'bg-white/20 text-white' : n > 0 ? 'bg-rose-100 text-rose-700' : 'bg-slate-100 text-slate-500'}">${n}</span></button>`;
  }).join('')}</div>`;
}

function approvalMatchesFilters(u, q) {
  const tab = state.approvalsFilterRole;
  if (tab && approvalKind(u) !== tab) return false;
  if (state.approvalsFilterParoki && !(String(u.paroki_id) === String(state.approvalsFilterParoki) || u.paroki_name === state.approvalsFilterParoki)) return false;
  if (!q) return true;
  return [u.full_name, u.email, u.phone_number, u.paroki_name, u.keuskupan_name, u.kota_name, u.lingkungan_name, u.ordo_name, u.address, u.provinsi_name]
    .some((v) => String(v || '').toLowerCase().includes(q));
}
