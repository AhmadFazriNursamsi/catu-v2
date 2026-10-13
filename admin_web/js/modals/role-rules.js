// ── Aturan ganti peran di form Edit Pengguna (sama dengan backend: modules/auth/registration-rules.ts) ──
// Umat -> Pengurus Lingkungan / Koordinator; Pengurus Lingkungan & Koordinator -> Umat; Umat Pendatang, Romo Paroki,
// dan Romo Ordo tidak dapat berganti peran (Romo hanya dapat diubah posisi pastoralnya).

const EDIT_ROLE_LABELS = {
  UMAT: 'Umat Katolik',
  UMAT_PENDATANG: 'Umat Pendatang',
  PENGURUS_LINGKUNGAN: 'Pengurus Lingkungan',
  KOORDINATOR: 'Koordinator Keuskupan',
  ROMO_PAROKI: 'Romo Paroki (Diosesan)',
  ROMO_ORDO: 'Romo Ordo (Religius)',
};

// Peran tersimpan (bukan pilihan dropdown yang sedang diubah); Koordinator disatukan, umat berjabatan dianggap pengurus.
function editOriginalRole(u) {
  const saved = state.users.find(x => String(x.id) === String(u.id)) || u;
  const role = (saved.role_code || saved.roleCode || 'UMAT').toUpperCase();
  const pos = (saved.pengurus_position || saved.pengurusPosition || '').trim().toLowerCase();
  if (role.startsWith('KOORDINATOR') || pos.includes('koordinator')) return 'KOORDINATOR';
  if (role === 'UMAT' && pos) return 'PENGURUS_LINGKUNGAN';
  return role;
}

const EDIT_ROLE_TARGETS = {
  UMAT: ['PENGURUS_LINGKUNGAN', 'KOORDINATOR'],
  PENGURUS_LINGKUNGAN: ['UMAT'],
  KOORDINATOR: ['UMAT'],
  UMAT_PENDATANG: [],
  ROMO_PAROKI: [],
  ROMO_ORDO: [],
};

const EDIT_ROLE_HINTS = {
  UMAT: 'Umat hanya dapat diubah menjadi Pengurus Lingkungan atau Koordinator.',
  PENGURUS_LINGKUNGAN: 'Pengurus Lingkungan hanya dapat diubah menjadi Umat.',
  KOORDINATOR: 'Koordinator hanya dapat diubah menjadi Umat.',
  UMAT_PENDATANG: 'Peran Umat Pendatang tidak dapat diubah.',
  ROMO_PAROKI: 'Peran Romo tidak dapat diubah. Ubah posisi pastoral di bagian bawah form.',
  ROMO_ORDO: 'Peran Romo tidak dapat diubah. Ubah posisi pastoral di bagian bawah form.',
};

function editAllowedRoles(originalRole) {
  const targets = EDIT_ROLE_TARGETS[originalRole];
  return targets ? [originalRole, ...targets] : Object.keys(EDIT_ROLE_LABELS);
}

function renderEditRoleSelect(u, roleCode) {
  const original = editOriginalRole(u);
  const allowed = editAllowedRoles(original);
  const locked = allowed.length === 1;
  const hint = EDIT_ROLE_HINTS[original] || '';
  const options = allowed.map(c => `<option value="${c}" ${roleCode === c ? 'selected' : ''}>${EDIT_ROLE_LABELS[c]}</option>`).join('');
  return `<select id="editRoleCode" ${locked ? 'disabled' : ''} onchange="syncEditFormToState(); onEditRoleChanged(this.value);"
      class="w-full px-4 py-2.5 border border-slate-200 rounded-xl font-black text-blue-950 text-xs focus:outline-none focus:ring-2 focus:ring-amber-500 shadow-xs transition ${locked ? 'bg-slate-100 cursor-not-allowed' : 'bg-white'}">${options}</select>
    ${hint ? `<p class="text-[11px] text-slate-500 font-semibold mt-1.5 flex items-center gap-1"><i data-lucide="info" class="w-3.5 h-3.5"></i>${hint}</p>` : ''}`;
}
