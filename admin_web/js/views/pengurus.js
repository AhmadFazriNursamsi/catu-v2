// ── Pengurus Management View ──
function renderPengurusTable(filteredPengurus) {
      return `<div class="overflow-x-auto">
              <table class="w-full text-left text-xs">
                <thead class="bg-slate-50 text-slate-600 font-bold border-b border-slate-200 tracking-wider uppercase text-[10.5px]">
                  <tr>
                    <th class="px-6 py-4">NAMA PENGURUS</th>
                    <th class="px-6 py-4">JABATAN</th>
                    <th class="px-6 py-4">KOTA / DOMISILI</th>
                    <th class="px-6 py-4">LINGKUNGAN & PAROKI</th>
                    <th class="px-6 py-4 text-center">STATUS JABATAN</th>
                    <th class="px-6 py-4">NO. WHATSAPP</th>
                    <th class="px-6 py-4 text-right">AKSI</th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-slate-100 font-medium text-slate-700">
                  ${filteredPengurus.length === 0 ? `
                    <tr>
                      <td colspan="7" class="text-center py-16 text-slate-400 space-y-3">
                        <div class="w-14 h-14 rounded-2xl bg-slate-50 border border-slate-200 flex items-center justify-center mx-auto text-slate-400">
                          <i data-lucide="award" class="w-7 h-7"></i>
                        </div>
                        <p class="font-bold text-slate-700 text-sm">Tidak ada data pengurus lingkungan yang sesuai filter</p>
                      </td>
                    </tr>
                  ` : filteredPengurus.map(u => {
                    const currentYear = new Date().getFullYear();
                    const endY = u.jabatan_end_year || (u.jabatan_end_date ? new Date(u.jabatan_end_date).getFullYear() : null);
                    const isExpired = (endY && endY < currentYear) || u.is_jabatan_active === false;
                    return `
                      <tr onclick="viewUserProfileModal('${u.id}')" class="hover:bg-slate-50/80 transition duration-150 cursor-pointer group">
                        <td class="px-6 py-4">
                          <p class="font-bold text-slate-900 text-sm tracking-tight group-hover:text-blue-900 transition">${u.full_name || 'Pengurus'}</p>
                          <p class="text-[11px] text-slate-400 font-medium truncate max-w-xs mt-0.5">${u.email || '-'}</p>
                        </td>
                        <td class="px-6 py-4 font-semibold text-slate-800 text-xs">
                          ${u.pengurus_position || 'Ketua Lingkungan'}
                        </td>
                        <td class="px-6 py-4 text-slate-700 font-medium text-xs">
                          <span class="truncate block max-w-[170px]">${u.kota_name || u.address || '-'}</span>
                        </td>
                        <td class="px-6 py-4 text-slate-700 font-medium text-xs">
                          <p class="font-semibold text-slate-800 truncate max-w-[180px]">${u.lingkungan_name || '-'}</p>
                          <p class="text-[11px] text-slate-400 font-medium truncate max-w-[180px] mt-0.5">${u.paroki_name || '-'}</p>
                        </td>
                        <td class="px-6 py-4 text-center">
                          ${isExpired ? `
                            <span class="inline-flex items-center space-x-1.5 px-2.5 py-0.5 rounded-full bg-rose-50 text-rose-700 border border-rose-200 font-bold text-[10.5px]">
                              <span class="w-1.5 h-1.5 rounded-full bg-rose-500"></span>
                              <span>TIDAK AKTIF</span>
                            </span>
                          ` : `
                            <span class="inline-flex items-center space-x-1.5 px-2.5 py-0.5 rounded-full bg-emerald-50 text-emerald-800 border border-emerald-200 font-bold text-[10.5px]">
                              <span class="w-1.5 h-1.5 rounded-full bg-emerald-500"></span>
                              <span>AKTIF</span>
                            </span>
                          `}
                        </td>
                        <td class="px-6 py-4 font-semibold text-slate-700">
                          <span class="inline-flex items-center space-x-1.5 text-xs">
                            <i data-lucide="phone" class="w-3.5 h-3.5 text-slate-400"></i>
                            <span>${u.phone_number}</span>
                          </span>
                        </td>
                        <td class="px-6 py-4 text-right">
                          <div class="inline-flex items-center justify-end space-x-2">
                            <button onclick="event.stopPropagation(); openEditUserModal('${u.id}')"
                              class="inline-flex items-center space-x-1 text-xs font-semibold text-slate-600 hover:text-slate-900 transition py-1 px-1.5 rounded hover:bg-slate-100">
                              <i data-lucide="edit-3" class="w-3.5 h-3.5 text-slate-500"></i>
                              <span>Edit</span>
                            </button>
                            <span class="text-slate-300">·</span>
                            <button onclick="event.stopPropagation(); viewUserProfileModal('${u.id}')"
                              class="inline-flex items-center space-x-1 text-xs font-semibold text-blue-700 hover:text-blue-900 transition py-1 px-1.5 rounded hover:bg-blue-50">
                              <i data-lucide="eye" class="w-3.5 h-3.5 text-blue-600"></i>
                              <span>Detail</span>
                            </button>
                          </div>
                        </td>
                      </tr>
                    `;
                  }).join('')}
                </tbody>
              </table>
            </div>
          </div>
        </div>`;
    }

    function renderPengurusTab() {
      const q = (state.pengurusSearch || '').toLowerCase().trim();
      const hasFilter = state.pengurusSearch || state.pengurusFilterPosition || state.pengurusFilterParoki;

      const allPengurusUsers = state.users.filter(u => (u.role_code || u.roleCode || '').toUpperCase() === 'PENGURUS_LINGKUNGAN');
      const parokiList = state.paroki?.length > 0 ? state.paroki : Array.from(new Set(allPengurusUsers.map(u => u.paroki_name).filter(Boolean))).map(name => ({ id: name, name }));
      const positionList = ['Ketua Lingkungan', 'Wakil Ketua', 'Sekretaris'];

      const list = state.users.filter(u => {
        const role = (u.role_code || u.roleCode || '').toUpperCase();
        const status = (u.account_status || u.accountStatus || '').toUpperCase();
        if (role !== 'PENGURUS_LINGKUNGAN' || status !== 'APPROVED') return false;

        if (state.pengurusFilterPosition) {
          if ((u.pengurus_position || '') !== state.pengurusFilterPosition) return false;
        }

        if (state.pengurusFilterParoki) {
          const matchPar = String(u.paroki_id) === String(state.pengurusFilterParoki) || (u.paroki_name === state.pengurusFilterParoki);
          if (!matchPar) return false;
        }

        if (q) {
          const name = (u.full_name || u.fullName || '').toLowerCase();
          const email = (u.email || '').toLowerCase();
          const phone = (u.phone_number || u.phoneNumber || '').toLowerCase();
          const pos = (u.pengurus_position || '').toLowerCase();
          const par = (u.paroki_name || u.parokiName || '').toLowerCase();
          const ling = (u.lingkungan_name || '').toLowerCase();
          const kota = (u.kota_name || u.address || '').toLowerCase();
          const prov = (u.provinsi_name || '').toLowerCase();
          if (!name.includes(q) && !email.includes(q) && !phone.includes(q) && !pos.includes(q) && !par.includes(q) && !ling.includes(q) && !kota.includes(q) && !prov.includes(q)) return false;
        }
        return true;
      });

      return `
        <div class="space-y-6 animate-fade-in">
          <div class="bg-white rounded-2xl border border-slate-200/90 shadow-sm overflow-hidden">
            <div class="p-6 border-b border-slate-200/80 bg-slate-50/50 flex flex-col lg:flex-row lg:items-center justify-between gap-4">
              <div class="relative w-full max-w-md">
                <i data-lucide="search" class="w-4 h-4 absolute left-3.5 top-1/2 -translate-y-1/2 text-slate-400"></i>
                <input type="text" id="pengurusSearchInput" placeholder="Cari nama pengurus, kota, email, jabatan..." value="${state.pengurusSearch}"
                  oninput="state.pengurusSearch = this.value; renderApp();"
                  class="w-full pl-10 pr-9 py-2.5 bg-white border border-slate-200 rounded-xl text-xs font-bold text-slate-900 focus:outline-none focus:ring-2 focus:ring-slate-400 shadow-sm transition" />
              </div>

              <div class="flex flex-wrap items-center gap-3">
                <div class="relative">
                  <select onchange="state.pengurusFilterPosition = this.value; renderApp();"
                    class="pl-3.5 pr-8 py-2.5 bg-white border border-slate-200 rounded-xl text-xs font-bold text-slate-800 focus:outline-none focus:ring-2 focus:ring-slate-400 shadow-sm">
                    <option value="">Semua Jabatan</option>
                    ${positionList.map(pos => `
                      <option value="${pos}" ${state.pengurusFilterPosition === pos ? 'selected' : ''}>${pos}</option>
                    `).join('')}
                  </select>
                </div>

                <div class="relative">
                  <select onchange="state.pengurusFilterParoki = this.value; renderApp();"
                    class="pl-3.5 pr-8 py-2.5 bg-white border border-slate-200 rounded-xl text-xs font-bold text-slate-800 focus:outline-none focus:ring-2 focus:ring-slate-400 shadow-sm max-w-[210px] truncate">
                    <option value="">Semua Paroki</option>
                    ${parokiList.map(p => `
                      <option value="${p.id || p.name}" ${String(state.pengurusFilterParoki) === String(p.id || p.name) ? 'selected' : ''}>${p.name}</option>
                    `).join('')}
                  </select>
                </div>

                ${hasFilter ? `
                  <button onclick="state.pengurusSearch = ''; state.pengurusFilterPosition = ''; state.pengurusFilterParoki = ''; renderApp();"
                    class="inline-flex items-center space-x-1 px-3 py-2 rounded-xl bg-slate-100 hover:bg-slate-200 text-slate-700 text-xs font-bold transition">
                    <i data-lucide="rotate-ccw" class="w-3.5 h-3.5 text-slate-500"></i>
                    <span>Reset</span>
                  </button>
                ` : ''}

                <span class="px-3.5 py-1.5 rounded-full bg-slate-100 text-slate-700 border border-slate-200 text-xs font-bold whitespace-nowrap">
                  ${list.length} Pengurus Aktif
                </span>
              </div>
            </div>

            ${renderPengurusTable(list)}
      `;
    }

    // ── Tab: Romo Paroki ──
