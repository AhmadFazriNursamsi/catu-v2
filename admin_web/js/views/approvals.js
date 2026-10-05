function renderApprovalsTable(pendings, hasFilter) {
  const tab = state.approvalsFilterRole || '';
  const showRole = !tab; // pada tab jenis akun tertentu, kolom peran redundan
  const cols = showRole ? 5 : 4;
  const tabLabel = (APPROVAL_TABS.find((t) => t.code === tab) || {}).label;
  return `<div class="overflow-x-auto">
    <table class="w-full min-w-[760px] text-left text-xs">
      <thead class="bg-slate-50 text-slate-600 font-bold border-b border-slate-200 tracking-wider uppercase text-[10.5px]">
        <tr>
          <th class="px-6 py-4">PEMOHON AKUN</th>
          <th class="px-6 py-4">NO. WHATSAPP</th>
          ${showRole ? '<th class="px-6 py-4">PERAN DIAJUKAN</th>' : ''}
          <th class="px-6 py-4">${approvalAssignmentHeader(tab)}</th>
          <th class="px-6 py-4 text-right">AKSI VERIFIKASI</th>
        </tr>
      </thead>
      <tbody class="divide-y divide-slate-100 font-medium text-slate-700">
        ${pendings.length === 0 ? `
          <tr><td colspan="${cols + 1}" class="text-center py-16 text-slate-400 space-y-3">
            <div class="w-14 h-14 rounded-2xl bg-slate-50 border border-slate-200 flex items-center justify-center mx-auto">
              <i data-lucide="${hasFilter ? 'search-x' : 'check-circle-2'}" class="w-7 h-7 ${hasFilter ? 'text-slate-400' : 'text-emerald-500'}"></i>
            </div>
            <p class="font-bold text-slate-700 text-sm">${hasFilter ? `Tidak ada pendaftaran${tabLabel ? ' ' + tabLabel : ''} yang cocok dengan kriteria` : 'Semua pendaftaran telah diverifikasi'}</p>
            ${hasFilter ? `<button onclick="state.approvalsSearch = ''; state.approvalsFilterRole = ''; state.approvalsFilterParoki = ''; renderApp();" class="inline-flex items-center space-x-1.5 px-3 py-1.5 rounded-lg bg-slate-100 hover:bg-slate-200 text-slate-700 font-bold text-xs transition cursor-pointer mt-2"><i data-lucide="rotate-ccw" class="w-3.5 h-3.5"></i><span>Reset Filter</span></button>` : ''}
          </td></tr>` : pendings.map((u) => `
          <tr onclick="viewUserProfileModal('${Number(u.id)}')" class="hover:bg-slate-50/80 transition duration-150 cursor-pointer group">
            <td class="px-6 py-4">
              <p class="font-bold text-slate-900 text-sm tracking-tight group-hover:text-blue-900 transition">${escapeApprovalHtml(u.full_name || 'Pengguna Baru')}</p>
              <p class="text-[11px] text-slate-400 font-medium truncate max-w-xs mt-0.5">${escapeApprovalHtml(u.email || '-')}</p>
              <p class="text-[10.5px] text-slate-400 mt-0.5">Daftar ${u.created_at ? escapeApprovalHtml(new Date(u.created_at).toLocaleString('id-ID', { dateStyle: 'medium', timeStyle: 'short' })) : '-'}</p>
            </td>
            <td class="px-6 py-4 font-bold text-slate-800"><span class="inline-flex items-center space-x-1.5 text-xs"><i data-lucide="phone" class="w-3.5 h-3.5 text-slate-400"></i><span>${escapeApprovalHtml(u.phone_number)}</span></span></td>
            ${showRole ? `<td class="px-6 py-4">${renderApprovalRoleBadge(u)}</td>` : ''}
            <td class="px-6 py-4">${renderApprovalAssignment(u)}</td>
            <td class="px-6 py-4 text-right">${renderApprovalActions(u)}</td>
          </tr>`).join('')}
      </tbody>
    </table>
  </div>`;
}

function renderApprovalsTab() {
  const q = (state.approvalsSearch || '').toLowerCase().trim();
  const hasFilter = state.approvalsSearch || state.approvalsFilterRole || state.approvalsFilterParoki;
  const allPending = state.users.filter((u) => (u.account_status || u.accountStatus || '').toUpperCase() === 'PENDING_APPROVAL');
  const parokiList = state.paroki?.length > 0 ? state.paroki : Array.from(new Set(allPending.map((u) => u.paroki_name).filter(Boolean))).map((name) => ({ id: name, name }));
  const pendings = allPending.filter((u) => approvalMatchesFilters(u, q));
  const parokiRelevant = ['', 'UMAT', 'PENGURUS_LINGKUNGAN', 'ROMO_PAROKI'].includes(state.approvalsFilterRole || '');

  return `
    <div class="space-y-6 animate-fade-in">
      <div class="bg-white rounded-2xl border border-slate-200/90 shadow-sm overflow-hidden">
        ${renderApprovalTabs(allPending)}
        <div class="p-4 sm:p-6 border-b border-slate-200/80 bg-slate-50/50 flex flex-col lg:flex-row lg:items-center justify-between gap-3 sm:gap-4">
          <div class="relative w-full max-w-md">
            <i data-lucide="search" class="w-4 h-4 absolute left-3.5 top-1/2 -translate-y-1/2 text-slate-400"></i>
            <input type="text" id="approvalsSearchInput" placeholder="Cari pemohon, nama, keuskupan, kota, nomor HP..." value="${escapeApprovalHtml(state.approvalsSearch)}"
              oninput="state.approvalsSearch = this.value; renderApp();"
              class="w-full pl-10 pr-9 py-2.5 bg-white border border-slate-200 rounded-xl text-xs font-bold text-slate-900 focus:outline-none focus:ring-2 focus:ring-slate-400 shadow-sm transition" />
          </div>
          <div class="flex flex-wrap items-center gap-2 sm:gap-3 w-full lg:w-auto">
            ${parokiRelevant ? `
              <select onchange="state.approvalsFilterParoki = this.value; renderApp();"
                class="w-full sm:w-auto pl-3.5 pr-8 py-2.5 bg-white border border-slate-200 rounded-xl text-xs font-bold text-slate-800 focus:outline-none focus:ring-2 focus:ring-slate-400 shadow-sm max-w-none sm:max-w-[210px] truncate">
                <option value="">Semua Paroki</option>
                ${parokiList.map((p) => `<option value="${escapeApprovalHtml(p.id || p.name)}" ${String(state.approvalsFilterParoki) === String(p.id || p.name) ? 'selected' : ''}>${escapeApprovalHtml(p.name)}</option>`).join('')}
              </select>` : ''}
            ${hasFilter ? `<button onclick="state.approvalsSearch = ''; state.approvalsFilterRole = ''; state.approvalsFilterParoki = ''; renderApp();"
              class="inline-flex items-center space-x-1 px-3 py-2 rounded-xl bg-slate-100 hover:bg-slate-200 text-slate-700 text-xs font-bold transition">
              <i data-lucide="rotate-ccw" class="w-3.5 h-3.5 text-slate-500"></i><span>Reset</span></button>` : ''}
            <span class="px-3.5 py-1.5 rounded-full bg-slate-100 text-slate-700 border border-slate-200 text-xs font-bold whitespace-nowrap">${pendings.length} Pendaftaran Menunggu</span>
          </div>
        </div>
        ${renderApprovalsTable(pendings, hasFilter)}
      </div>
    </div>`;
}
