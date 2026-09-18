// ── Registration Approvals View & Confirmation Modal ──
function renderApprovalsTable(pendings) {
      return `<div class="overflow-x-auto">
              <table class="w-full min-w-[760px] text-left text-xs">
                <thead class="bg-slate-50 text-slate-600 font-bold border-b border-slate-200 tracking-wider uppercase text-[10.5px]">
                  <tr>
                    <th class="px-6 py-4">PEMOHON AKUN</th>
                    <th class="px-6 py-4">NO. WHATSAPP</th>
                    <th class="px-6 py-4">PERAN DIAJUKAN</th>
                    <th class="px-6 py-4">KEUSKUPAN & DOMISILI</th>
                    <th class="px-6 py-4">PAROKI & LINGKUNGAN</th>
                    <th class="px-6 py-4 text-right">AKSI VERIFIKASI</th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-slate-100 font-medium text-slate-700">
                  ${pendings.length === 0 ? `
                    <tr>
                      <td colspan="6" class="text-center py-16 text-slate-400 space-y-3">
                        <div class="w-14 h-14 rounded-2xl bg-slate-50 border border-slate-200 text-slate-400 flex items-center justify-center mx-auto">
                          <i data-lucide="check-circle-2" class="w-7 h-7"></i>
                        </div>
                        <p class="font-bold text-slate-700 text-sm">Semua pendaftaran telah diverifikasi</p>
                      </td>
                    </tr>
                  ` : pendings.map(u => `
                    <tr class="hover:bg-slate-50/80 transition duration-150 group">
                      <td class="px-6 py-4">
                        <p class="font-bold text-slate-900 text-sm tracking-tight">${u.full_name || 'Pengguna Baru'}</p>
                        <p class="text-[11px] text-slate-400 font-medium truncate max-w-xs mt-0.5">${u.email || '-'}</p>
                      </td>
                      <td class="px-6 py-4 font-bold text-slate-800">
                        <span class="inline-flex items-center space-x-1.5 text-xs">
                          <i data-lucide="phone" class="w-3.5 h-3.5 text-slate-400"></i>
                          <span>${u.phone_number}</span>
                        </span>
                      </td>
                      <td class="px-6 py-4">
                        ${(() => {
                          const r = (u.role_code || '').toUpperCase();
                          const pos = (u.pengurus_position || u.pengurusPosition || '').toString().toLowerCase();
                          const isKoordinator = pos.includes('koordinator') || r === 'KOORDINATOR';

                          if (isKoordinator) {
                            return `
                              <span class="inline-flex items-center space-x-1.5 px-3 py-1.5 rounded-xl bg-indigo-50 text-indigo-900 border border-indigo-300 font-bold text-xs shadow-2xs">
                                <i data-lucide="award" class="w-3.5 h-3.5 text-indigo-600"></i>
                                <span>KOORDINATOR (KEUSKUPAN)</span>
                              </span>
                            `;
                          }
                          const bgClass = r === 'UMAT' ? 'bg-blue-50 text-blue-900 border-blue-200'
                            : r === 'PENGURUS_LINGKUNGAN' ? 'bg-indigo-50 text-indigo-900 border-indigo-200'
                            : r === 'ROMO_PAROKI' ? 'bg-emerald-50 text-emerald-900 border-emerald-200'
                            : r === 'ROMO_ORDO' ? 'bg-purple-50 text-purple-900 border-purple-200'
                            : 'bg-amber-50 text-amber-900 border-amber-200';
                          return `
                            <span class="inline-flex items-center space-x-1.5 px-3 py-1.5 rounded-xl ${bgClass} border font-bold text-xs shadow-2xs">
                              <i data-lucide="shield" class="w-3.5 h-3.5"></i>
                              <span>${u.role_name || u.role_code}</span>
                            </span>
                          `;
                        })()}
                      </td>
                      <td class="px-6 py-4">
                        <div class="inline-flex flex-col">
                          ${u.keuskupan_name ? `<span class="font-bold text-slate-900 text-xs">${u.keuskupan_name}</span>` : ''}
                          <span class="text-[11px] text-slate-500">${u.kota_name || u.address || '-'}</span>
                        </div>
                      </td>
                      <td class="px-6 py-4">
                        <div class="inline-flex flex-col">
                          <span class="font-bold text-slate-800 text-xs">${u.paroki_name || '-'}</span>
                          ${u.lingkungan_name ? `<span class="text-[11px] text-slate-400">Lkg. ${u.lingkungan_name}</span>` : ''}
                        </div>
                      </td>
                      <td class="px-6 py-4 text-right">
                        ${(() => {
                          const r = (u.role_code || u.roleCode || '').toUpperCase();
                          const pos = (u.pengurus_position || u.pengurusPosition || '').toString().toLowerCase();
                          const isKoordinator = pos.includes('koordinator') || r === 'KOORDINATOR';

                          if (r === 'UMAT' && !isKoordinator) {
                            return `
                              <div class="inline-flex items-center space-x-1.5 px-3 py-1.5 rounded-xl bg-amber-50 text-amber-900 border border-amber-200/80 font-bold text-[11px] shadow-2xs" title="Persetujuan pendaftaran Umat dilakukan oleh Pengurus Lingkungan via aplikasi mobile CATU">
                                <i data-lucide="shield-alert" class="w-3.5 h-3.5 text-amber-600"></i>
                                <span>Verifikasi Pengurus Lingkungan</span>
                              </div>
                            `;
                          }
                          return `
                            <div class="inline-flex items-center justify-end space-x-2">
                              <button onclick="approveUserAction('${u.id}', 'APPROVED')" 
                                class="px-3.5 py-1.5 rounded-xl bg-emerald-600 hover:bg-emerald-700 text-white font-bold text-xs flex items-center space-x-1 transition shadow-md shadow-emerald-600/20 transform hover:-translate-y-0.5 cursor-pointer">
                                <i data-lucide="check" class="w-3.5 h-3.5"></i>
                                <span>Setujui</span>
                              </button>
                              <button onclick="approveUserAction('${u.id}', 'REJECTED')" 
                                class="px-3.5 py-1.5 rounded-xl bg-rose-600 hover:bg-rose-700 text-white font-bold text-xs flex items-center space-x-1 transition shadow-md shadow-rose-600/20 transform hover:-translate-y-0.5 cursor-pointer">
                                <i data-lucide="x" class="w-3.5 h-3.5"></i>
                                <span>Tolak</span>
                              </button>
                            </div>
                          `;
                        })()}
                      </td>
                    </tr>
                  `).join('')}
                </tbody>
              </table>
            </div>`;
    }

    function renderApprovalsTab() {
      const q = (state.approvalsSearch || '').toLowerCase().trim();
      const hasFilter = state.approvalsSearch || state.approvalsFilterRole || state.approvalsFilterParoki;

      const allPendingUsers = state.users.filter(u => (u.account_status || u.accountStatus || '').toUpperCase() === 'PENDING_APPROVAL');
      const parokiList = state.paroki?.length > 0 ? state.paroki : Array.from(new Set(allPendingUsers.map(u => u.paroki_name).filter(Boolean))).map(name => ({ id: name, name }));
      const roleList = [
        { code: 'KOORDINATOR', name: '⭐ Koordinator (Keuskupan)' },
        { code: 'UMAT', name: 'Umat Katolik' },
        { code: 'PENGURUS_LINGKUNGAN', name: 'Pengurus Lingkungan' },
        { code: 'ROMO_PAROKI', name: 'Romo Paroki' },
        { code: 'ROMO_ORDO', name: 'Romo Ordo' }
      ];

      const pendings = state.users.filter(u => {
        const status = (u.account_status || u.accountStatus || '').toUpperCase();
        if (status !== 'PENDING_APPROVAL') return false;

        if (state.approvalsFilterRole) {
          const role = (u.role_code || u.roleCode || '').toUpperCase();
          const pos = (u.pengurus_position || u.pengurusPosition || '').toString().toLowerCase();
          const isKoor = pos.includes('koordinator') || role === 'KOORDINATOR';

          if (state.approvalsFilterRole === 'KOORDINATOR') {
            if (!isKoor) return false;
          } else if (state.approvalsFilterRole === 'UMAT') {
            if (isKoor || role !== 'UMAT') return false;
          } else if (role !== state.approvalsFilterRole) {
            return false;
          }
        }

        if (state.approvalsFilterParoki) {
          const matchPar = String(u.paroki_id) === String(state.approvalsFilterParoki) || (u.paroki_name === state.approvalsFilterParoki);
          if (!matchPar) return false;
        }

        if (q) {
          const name = (u.full_name || u.fullName || '').toLowerCase();
          const email = (u.email || '').toLowerCase();
          const phone = (u.phone_number || u.phoneNumber || '').toLowerCase();
          const par = (u.paroki_name || u.kota_name || '').toLowerCase();
          const keus = (u.keuskupan_name || '').toLowerCase();
          const kota = (u.kota_name || u.address || '').toLowerCase();
          const prov = (u.provinsi_name || '').toLowerCase();
          if (!name.includes(q) && !email.includes(q) && !phone.includes(q) && !par.includes(q) && !keus.includes(q) && !kota.includes(q) && !prov.includes(q)) return false;
        }
        return true;
      });

      return `
        <div class="space-y-6 animate-fade-in">
          <div class="bg-white rounded-2xl border border-slate-200/90 shadow-sm overflow-hidden">
            <div class="p-4 sm:p-6 border-b border-slate-200/80 bg-slate-50/50 flex flex-col lg:flex-row lg:items-center justify-between gap-3 sm:gap-4">
              <div class="relative w-full max-w-md">
                <i data-lucide="search" class="w-4 h-4 absolute left-3.5 top-1/2 -translate-y-1/2 text-slate-400"></i>
                <input type="text" id="approvalsSearchInput" placeholder="Cari pemohon, nama, keuskupan, kota, nomor HP..." value="${state.approvalsSearch}"
                  oninput="state.approvalsSearch = this.value; renderApp();"
                  class="w-full pl-10 pr-9 py-2.5 bg-white border border-slate-200 rounded-xl text-xs font-bold text-slate-900 focus:outline-none focus:ring-2 focus:ring-slate-400 shadow-sm transition" />
              </div>

              <div class="flex flex-wrap items-center gap-2 sm:gap-3 w-full lg:w-auto">
                <div class="relative w-full sm:w-auto">
                  <select onchange="state.approvalsFilterRole = this.value; renderApp();"
                    class="w-full sm:w-auto pl-3.5 pr-8 py-2.5 bg-white border border-slate-200 rounded-xl text-xs font-bold text-slate-800 focus:outline-none focus:ring-2 focus:ring-slate-400 shadow-sm">
                    <option value="">Semua Peran Akun</option>
                    ${roleList.map(r => `
                      <option value="${r.code}" ${state.approvalsFilterRole === r.code ? 'selected' : ''}>${r.name}</option>
                    `).join('')}
                  </select>
                </div>

                <div class="relative w-full sm:w-auto">
                  <select onchange="state.approvalsFilterParoki = this.value; renderApp();"
                    class="w-full sm:w-auto pl-3.5 pr-8 py-2.5 bg-white border border-slate-200 rounded-xl text-xs font-bold text-slate-800 focus:outline-none focus:ring-2 focus:ring-slate-400 shadow-sm max-w-none sm:max-w-[210px] truncate">
                    <option value="">Semua Paroki</option>
                    ${parokiList.map(p => `
                      <option value="${p.id || p.name}" ${String(state.approvalsFilterParoki) === String(p.id || p.name) ? 'selected' : ''}>${p.name}</option>
                    `).join('')}
                  </select>
                </div>

                ${hasFilter ? `
                  <button onclick="state.approvalsSearch = ''; state.approvalsFilterRole = ''; state.approvalsFilterParoki = ''; renderApp();"
                    class="inline-flex items-center space-x-1 px-3 py-2 rounded-xl bg-slate-100 hover:bg-slate-200 text-slate-700 text-xs font-bold transition">
                    <i data-lucide="rotate-ccw" class="w-3.5 h-3.5 text-slate-500"></i>
                    <span>Reset</span>
                  </button>
                ` : ''}

                <span class="px-3.5 py-1.5 rounded-full bg-slate-100 text-slate-700 border border-slate-200 text-xs font-bold whitespace-nowrap">
                  ${pendings.length} Pendaftaran Menunggu
                </span>
              </div>
            </div>

            ${renderApprovalsTable(pendings)}
          </div>
        </div>
      `;
    }

    // ══════════════════════════════════════════════════════════════════════════
    // 3. MASTER DATA TAB (FULL DATABASE CRUD & BEAUTIFIED UI)
    // ══════════════════════════════════════════════════════════════════════════

    function renderActionConfirmModal() {
      const modal = state.actionConfirmModal;
      if (!modal) return '';

      return `
        <div class="fixed inset-0 z-[9999] bg-black/60 backdrop-blur-sm flex items-center justify-center p-4 animate-fade-in">
          <div class="bg-white rounded-2xl max-w-md w-full p-6 shadow-xl border border-slate-200 space-y-5">
            <div class="flex items-start space-x-4">
              <div class="w-12 h-12 rounded-2xl ${modal.iconBg || 'bg-blue-50 text-blue-700 border-blue-200'} border flex items-center justify-center flex-shrink-0 shadow-xs">
                <i data-lucide="${modal.icon || 'help-circle'}" class="w-6 h-6"></i>
              </div>
              <div class="flex-1 min-w-0">
                <h3 class="text-base font-black text-slate-900">${modal.title || 'Konfirmasi Tindakan'}</h3>
                <div class="text-xs text-slate-600 mt-1.5 leading-relaxed">
                  ${modal.subtitle || 'Apakah Anda yakin ingin melanjutkan tindakan ini?'}
                </div>
              </div>
            </div>

            <div class="pt-3 border-t border-slate-100 flex items-center justify-end space-x-2.5">
              <button onclick="state.actionConfirmModal = null; renderApp();"
                class="px-4 py-2.5 rounded-xl bg-slate-100 hover:bg-slate-200 text-slate-700 font-black text-xs transition">
                ${modal.cancelText || 'Batal'}
              </button>
              <button onclick="if(state.actionConfirmModal && state.actionConfirmModal.onConfirm) state.actionConfirmModal.onConfirm();"
                class="px-5 py-2.5 rounded-xl text-white font-black text-xs shadow-md transition transform hover:-translate-y-0.5 cursor-pointer ${modal.confirmBtnClass || 'bg-blue-950 hover:bg-slate-900'}">
                ${modal.confirmText || 'Konfirmasi'}
              </button>
            </div>
          </div>
        </div>
      `;
    }
