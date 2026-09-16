// ── Umat Management View ──
function renderUmatTable(filteredUmat) {
      return `<div class="overflow-x-auto">
              <table class="w-full text-left text-xs">
                <thead class="bg-slate-50 text-slate-600 font-bold border-b border-slate-200 tracking-wider uppercase text-[10.5px]">
                  <tr>
                    <th class="px-6 py-4">NAMA LENGKAP UMAT</th>
                    <th class="px-6 py-4">NO. WHATSAPP</th>
                    <th class="px-6 py-4">KOTA / DOMISILI</th>
                    <th class="px-6 py-4">PAROKI</th>
                    <th class="px-6 py-4">LINGKUNGAN & WILAYAH</th>
                    <th class="px-6 py-4 text-center">STATUS AKUN</th>
                    <th class="px-6 py-4 text-right">AKSI</th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-slate-100 font-medium text-slate-700">
                  ${filteredUmat.length === 0 ? `
                    <tr>
                      <td colspan="7" class="text-center py-16 text-slate-400 space-y-3">
                        <div class="w-14 h-14 rounded-2xl bg-slate-50 border border-slate-200 flex items-center justify-center mx-auto text-slate-400">
                          <i data-lucide="users" class="w-7 h-7"></i>
                        </div>
                        <p class="font-bold text-slate-700 text-sm">Tidak ada data umat yang sesuai filter</p>
                      </td>
                    </tr>
                  ` : filteredUmat.map(u => `
                    <tr class="hover:bg-slate-50/80 transition duration-150 group">
                      <td class="px-6 py-4">
                        <p class="font-bold text-slate-900 text-sm tracking-tight">${u.full_name || 'Umat'}</p>
                        <p class="text-[11px] text-slate-400 font-medium truncate max-w-xs mt-0.5">${u.email || '-'}</p>
                      </td>
                      <td class="px-6 py-4 font-bold text-slate-800">
                        <span class="inline-flex items-center space-x-1.5 text-xs">
                          <i data-lucide="phone" class="w-3.5 h-3.5 text-slate-400"></i>
                          <span>${u.phone_number}</span>
                        </span>
                      </td>
                      <td class="px-6 py-4">
                        <div class="inline-flex items-center space-x-1.5 px-3 py-1 rounded-xl bg-slate-100 text-slate-700 font-bold border border-slate-200 text-xs shadow-sm">
                          <i data-lucide="map-pin" class="w-3.5 h-3.5 text-slate-400"></i>
                          <span class="truncate max-w-[170px]">${u.kota_name || u.address || '-'}</span>
                        </div>
                      </td>
                      <td class="px-6 py-4">
                        <div class="inline-flex items-center px-3 py-1 rounded-xl bg-slate-100 text-slate-700 font-bold border border-slate-200 text-xs shadow-sm">
                          <span>${u.paroki_name || u.kota_name || '-'}</span>
                        </div>
                      </td>
                      <td class="px-6 py-4">
                        <div class="inline-flex items-center px-3 py-1 rounded-xl bg-slate-100 text-slate-700 font-bold border border-slate-200 text-xs shadow-sm">
                          <span>${u.lingkungan_name || u.wilayah_name || '-'}</span>
                        </div>
                      </td>
                      <td class="px-6 py-4 text-center">
                        <span class="inline-flex items-center space-x-1.5 px-3 py-1 rounded-full bg-emerald-50 text-emerald-800 border border-emerald-200 font-bold text-[11px] shadow-sm">
                          <span class="w-1.5 h-1.5 rounded-full bg-emerald-500"></span>
                          <span>AKTIF</span>
                        </span>
                      </td>
                      <td class="px-6 py-4 text-right">
                        <div class="inline-flex items-center justify-end space-x-2">
                          <button onclick="openEditUserModal('${u.id}')"
                            class="inline-flex items-center space-x-1.5 px-3 py-1.5 rounded-xl bg-amber-50 hover:bg-amber-100 text-amber-900 font-bold border border-amber-200 text-xs transition shadow-sm transform hover:-translate-y-0.5">
                            <i data-lucide="edit" class="w-3.5 h-3.5 text-amber-600"></i>
                            <span>Edit</span>
                          </button>
                          <button onclick="viewUserProfileModal('${u.id}')"
                            class="inline-flex items-center space-x-1 px-3 py-1.5 rounded-xl bg-blue-50 hover:bg-blue-100 text-blue-900 font-bold border border-blue-200 text-xs transition shadow-sm transform hover:-translate-y-0.5">
                            <i data-lucide="eye" class="w-3.5 h-3.5 text-blue-600"></i>
                            <span>Detail</span>
                          </button>
                        </div>
                      </td>
                    </tr>
                  `).join('')}
                </tbody>
              </table>
            </div>
          </div>
        </div>`;
    }

    function renderUmatTab() {
      const q = (state.umatSearch || '').toLowerCase().trim();
      const hasFilter = state.umatSearch || state.umatFilterParoki || state.umatFilterLingkungan;

      // Extract unique paroki & lingkungan for filter options
      const allUmatUsers = state.users.filter(u => (u.role_code || u.roleCode || '').toUpperCase() === 'UMAT');
      const parokiList = state.paroki?.length > 0 ? state.paroki : Array.from(new Set(allUmatUsers.map(u => u.paroki_name).filter(Boolean))).map(name => ({ id: name, name }));
      const lingList = Array.from(new Set(
        allUmatUsers
          .filter(u => !state.umatFilterParoki || String(u.paroki_id) === String(state.umatFilterParoki) || u.paroki_name === state.umatFilterParoki)
          .map(u => u.lingkungan_name)
          .filter(Boolean)
      )).sort();

      const umats = state.users.filter(u => {
        const role = (u.role_code || u.roleCode || '').toUpperCase();
        const status = (u.account_status || u.accountStatus || '').toUpperCase();
        if (role !== 'UMAT' || status !== 'APPROVED') return false;

        if (state.umatFilterParoki) {
          const matchPar = String(u.paroki_id) === String(state.umatFilterParoki) || (u.paroki_name === state.umatFilterParoki);
          if (!matchPar) return false;
        }

        if (state.umatFilterLingkungan) {
          const matchLing = String(u.lingkungan_id) === String(state.umatFilterLingkungan) || (u.lingkungan_name === state.umatFilterLingkungan);
          if (!matchLing) return false;
        }

        if (q) {
          const name = (u.full_name || u.fullName || '').toLowerCase();
          const email = (u.email || '').toLowerCase();
          const phone = (u.phone_number || u.phoneNumber || '').toLowerCase();
          const par = (u.paroki_name || u.parokiName || '').toLowerCase();
          const ling = (u.lingkungan_name || '').toLowerCase();
          const kota = (u.kota_name || u.address || '').toLowerCase();
          const prov = (u.provinsi_name || '').toLowerCase();
          if (!name.includes(q) && !email.includes(q) && !phone.includes(q) && !par.includes(q) && !ling.includes(q) && !kota.includes(q) && !prov.includes(q)) return false;
        }
        return true;
      });

      return `
        <div class="space-y-6 animate-fade-in">
          <div class="bg-white rounded-3xl border border-slate-200/90 shadow-sm overflow-hidden">
            <div class="p-6 border-b border-slate-200/80 bg-slate-50/50 flex flex-col lg:flex-row lg:items-center justify-between gap-4">
              <div class="relative w-full max-w-md">
                <i data-lucide="search" class="w-4 h-4 absolute left-3.5 top-1/2 -translate-y-1/2 text-slate-400"></i>
                <input type="text" id="umatSearchInput" placeholder="Cari nama umat, kota, no. WhatsApp, paroki..." value="${state.umatSearch}"
                  oninput="state.umatSearch = this.value; renderApp();"
                  class="w-full pl-10 pr-9 py-2.5 bg-white border border-slate-200 rounded-xl text-xs font-bold text-slate-900 focus:outline-none focus:ring-2 focus:ring-slate-400 shadow-sm transition" />
              </div>

              <div class="flex flex-wrap items-center gap-3">
                <div class="relative">
                  <select onchange="state.umatFilterParoki = this.value; renderApp();"
                    class="pl-3.5 pr-8 py-2.5 bg-white border border-slate-200 rounded-xl text-xs font-bold text-slate-800 focus:outline-none focus:ring-2 focus:ring-slate-400 shadow-sm max-w-[210px] truncate">
                    <option value="">Semua Paroki</option>
                    ${parokiList.map(p => `
                      <option value="${p.id || p.name}" ${String(state.umatFilterParoki) === String(p.id || p.name) ? 'selected' : ''}>${p.name}</option>
                    `).join('')}
                  </select>
                </div>

                <div class="relative">
                  <select onchange="state.umatFilterLingkungan = this.value; renderApp();"
                    class="pl-3.5 pr-8 py-2.5 bg-white border border-slate-200 rounded-xl text-xs font-bold text-slate-800 focus:outline-none focus:ring-2 focus:ring-slate-400 shadow-sm max-w-[200px] truncate">
                    <option value="">Semua Lingkungan</option>
                    ${lingList.map(l => `
                      <option value="${l}" ${state.umatFilterLingkungan === l ? 'selected' : ''}>${l}</option>
                    `).join('')}
                  </select>
                </div>

                ${hasFilter ? `
                  <button onclick="state.umatSearch = ''; state.umatFilterParoki = ''; state.umatFilterLingkungan = ''; renderApp();"
                    class="inline-flex items-center space-x-1 px-3 py-2 rounded-xl bg-slate-100 hover:bg-slate-200 text-slate-700 text-xs font-bold transition">
                    <i data-lucide="rotate-ccw" class="w-3.5 h-3.5 text-slate-500"></i>
                    <span>Reset</span>
                  </button>
                ` : ''}

                <span class="px-3.5 py-1.5 rounded-full bg-slate-100 text-slate-700 border border-slate-200 text-xs font-bold whitespace-nowrap">
                  ${umats.length} Umat Terdaftar
                </span>
              </div>
            </div>

            ${renderUmatTable(umats)}
      `;
    }

    // ── Tab: Pengurus Lingkungan ──
