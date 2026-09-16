// ── Romo Paroki & Romo Ordo Management Views ──
function renderRomoParokiTable(filtered) {
      return `<div class="overflow-x-auto">
              <table class="w-full text-left text-xs">
                <thead class="bg-slate-50 text-slate-600 font-bold border-b border-slate-200 tracking-wider uppercase text-[10.5px]">
                  <tr>
                    <th class="px-6 py-4">NAMA ROMO</th>
                    <th class="px-6 py-4">KOTA / DOMISILI</th>
                    <th class="px-6 py-4">PAROKI</th>
                    <th class="px-6 py-4">JABATAN PASTORAL</th>
                    <th class="px-6 py-4">NO. WHATSAPP</th>
                    <th class="px-6 py-4 text-right">AKSI</th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-slate-100 font-medium text-slate-700">
                  ${filtered.length === 0 ? `
                    <tr>
                      <td colspan="6" class="text-center py-16 text-slate-400 space-y-3">
                        <div class="w-14 h-14 rounded-2xl bg-slate-50 border border-slate-200 flex items-center justify-center mx-auto text-slate-400">
                          <i data-lucide="church" class="w-7 h-7"></i>
                        </div>
                        <p class="font-bold text-slate-700 text-sm">Tidak ada Romo Paroki yang sesuai filter</p>
                      </td>
                    </tr>
                  ` : filtered.map(u => `
                    <tr class="hover:bg-slate-50/80 transition duration-150 group">
                      <td class="px-6 py-4">
                        <p class="font-bold text-slate-900 text-sm tracking-tight">${u.full_name || 'Romo Paroki'}</p>
                        <p class="text-[11px] text-slate-400 font-medium truncate max-w-xs mt-0.5">${u.email || '-'}</p>
                      </td>
                      <td class="px-6 py-4">
                        <div class="inline-flex items-center space-x-1.5 px-3 py-1 rounded-xl bg-slate-100 text-slate-700 font-bold border border-slate-200 text-xs shadow-sm">
                          <i data-lucide="map-pin" class="w-3.5 h-3.5 text-slate-400"></i>
                          <span class="truncate max-w-[170px]">${u.kota_name || u.address || '-'}</span>
                        </div>
                      </td>
                      <td class="px-6 py-4">
                        <div class="inline-flex items-center px-3 py-1 rounded-xl bg-slate-100 text-slate-700 font-bold border border-slate-200 text-xs shadow-sm">
                          <span>${u.paroki_name || '-'}</span>
                        </div>
                      </td>
                      <td class="px-6 py-4">
                        ${getUserPositionBadge(u.romo_position || 'Romo Paroki', 'ROMO_PAROKI')}
                      </td>
                      <td class="px-6 py-4 font-bold text-slate-800">
                        <span class="inline-flex items-center space-x-1.5 text-xs">
                          <i data-lucide="phone" class="w-3.5 h-3.5 text-slate-400"></i>
                          <span>${u.phone_number}</span>
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

    function renderRomoParokiTab() {
      const q = (state.romoParokiSearch || '').toLowerCase().trim();
      const hasFilter = state.romoParokiSearch || state.romoParokiFilterPosition || state.romoParokiFilterParoki;

      const allRomoParokiUsers = state.users.filter(u => (u.role_code || u.roleCode || '').toUpperCase() === 'ROMO_PAROKI');
      const parokiList = state.paroki?.length > 0 ? state.paroki : Array.from(new Set(allRomoParokiUsers.map(u => u.paroki_name).filter(Boolean))).map(name => ({ id: name, name }));
      const positionList = ['Kepala Romo Paroki', 'Romo Paroki'];

      const list = state.users.filter(u => {
        const role = (u.role_code || u.roleCode || '').toUpperCase();
        const status = (u.account_status || u.accountStatus || '').toUpperCase();
        if (role !== 'ROMO_PAROKI' || status !== 'APPROVED') return false;

        if (state.romoParokiFilterPosition) {
          if ((u.romo_position || '') !== state.romoParokiFilterPosition) return false;
        }

        if (state.romoParokiFilterParoki) {
          const matchPar = String(u.paroki_id) === String(state.romoParokiFilterParoki) || (u.paroki_name === state.romoParokiFilterParoki);
          if (!matchPar) return false;
        }

        if (q) {
          const name = (u.full_name || u.fullName || '').toLowerCase();
          const email = (u.email || '').toLowerCase();
          const phone = (u.phone_number || u.phoneNumber || '').toLowerCase();
          const pos = (u.romo_position || '').toLowerCase();
          const par = (u.paroki_name || u.parokiName || '').toLowerCase();
          const kota = (u.kota_name || u.address || '').toLowerCase();
          const prov = (u.provinsi_name || '').toLowerCase();
          if (!name.includes(q) && !email.includes(q) && !phone.includes(q) && !pos.includes(q) && !par.includes(q) && !kota.includes(q) && !prov.includes(q)) return false;
        }
        return true;
      });

      return `
        <div class="space-y-6 animate-fade-in">
          <div class="bg-white rounded-3xl border border-slate-200/90 shadow-sm overflow-hidden">
            <div class="p-6 border-b border-slate-200/80 bg-slate-50/50 flex flex-col lg:flex-row lg:items-center justify-between gap-4">
              <div class="relative w-full max-w-md">
                <i data-lucide="search" class="w-4 h-4 absolute left-3.5 top-1/2 -translate-y-1/2 text-slate-400"></i>
                <input type="text" id="romoParokiSearchInput" placeholder="Cari Romo Paroki, nama, kota, email, paroki..." value="${state.romoParokiSearch}"
                  oninput="state.romoParokiSearch = this.value; renderApp();"
                  class="w-full pl-10 pr-9 py-2.5 bg-white border border-slate-200 rounded-xl text-xs font-bold text-slate-900 focus:outline-none focus:ring-2 focus:ring-slate-400 shadow-sm transition" />
              </div>

              <div class="flex flex-wrap items-center gap-3">
                <div class="relative">
                  <select onchange="state.romoParokiFilterPosition = this.value; renderApp();"
                    class="pl-3.5 pr-8 py-2.5 bg-white border border-slate-200 rounded-xl text-xs font-bold text-slate-800 focus:outline-none focus:ring-2 focus:ring-slate-400 shadow-sm">
                    <option value="">Semua Posisi Pastoral</option>
                    ${positionList.map(pos => `
                      <option value="${pos}" ${state.romoParokiFilterPosition === pos ? 'selected' : ''}>${pos}</option>
                    `).join('')}
                  </select>
                </div>

                <div class="relative">
                  <select onchange="state.romoParokiFilterParoki = this.value; renderApp();"
                    class="pl-3.5 pr-8 py-2.5 bg-white border border-slate-200 rounded-xl text-xs font-bold text-slate-800 focus:outline-none focus:ring-2 focus:ring-slate-400 shadow-sm max-w-[210px] truncate">
                    <option value="">Semua Paroki</option>
                    ${parokiList.map(p => `
                      <option value="${p.id || p.name}" ${String(state.romoParokiFilterParoki) === String(p.id || p.name) ? 'selected' : ''}>${p.name}</option>
                    `).join('')}
                  </select>
                </div>

                ${hasFilter ? `
                  <button onclick="state.romoParokiSearch = ''; state.romoParokiFilterPosition = ''; state.romoParokiFilterParoki = ''; renderApp();"
                    class="inline-flex items-center space-x-1 px-3 py-2 rounded-xl bg-slate-100 hover:bg-slate-200 text-slate-700 text-xs font-bold transition">
                    <i data-lucide="rotate-ccw" class="w-3.5 h-3.5 text-slate-500"></i>
                    <span>Reset</span>
                  </button>
                ` : ''}

                <span class="px-3.5 py-1.5 rounded-full bg-slate-100 text-slate-700 border border-slate-200 text-xs font-bold whitespace-nowrap">
                  ${list.length} Romo Paroki
                </span>
              </div>
            </div>

            ${renderRomoParokiTable(list)}
      `;
    }

    // ── Tab: Romo Ordo ──
    function renderRomoOrdoTab() {
      const q = (state.romoOrdoSearch || '').toLowerCase().trim();
      const hasFilter = state.romoOrdoSearch || state.romoOrdoFilterOrdo || state.romoOrdoFilterPosition;

      const allRomoOrdoUsers = state.users.filter(u => (u.role_code || u.roleCode || '').toUpperCase() === 'ROMO_ORDO');
      const ordoList = state.ordo?.length > 0 ? state.ordo : Array.from(new Set(allRomoOrdoUsers.map(u => u.ordo_name).filter(Boolean))).map(name => ({ id: name, name }));
      const positionList = ['Ketua Romo Ordo', 'Romo Ordo'];

      const list = state.users.filter(u => {
        const role = (u.role_code || u.roleCode || '').toUpperCase();
        const status = (u.account_status || u.accountStatus || '').toUpperCase();
        if (role !== 'ROMO_ORDO' || status !== 'APPROVED') return false;

        if (state.romoOrdoFilterOrdo) {
          const matchOrdo = String(u.ordo_id) === String(state.romoOrdoFilterOrdo) || (u.ordo_name === state.romoOrdoFilterOrdo);
          if (!matchOrdo) return false;
        }

        if (state.romoOrdoFilterPosition) {
          if ((u.romo_position || '') !== state.romoOrdoFilterPosition) return false;
        }

        if (q) {
          const name = (u.full_name || u.fullName || '').toLowerCase();
          const email = (u.email || '').toLowerCase();
          const phone = (u.phone_number || u.phoneNumber || '').toLowerCase();
          const pos = (u.romo_position || '').toLowerCase();
          const ordo = (u.ordo_name || '').toLowerCase();
          const kota = (u.kota_name || u.address || '').toLowerCase();
          const prov = (u.provinsi_name || '').toLowerCase();
          if (!name.includes(q) && !email.includes(q) && !phone.includes(q) && !pos.includes(q) && !ordo.includes(q) && !kota.includes(q) && !prov.includes(q)) return false;
        }
        return true;
      });

      return `
        <div class="space-y-6 animate-fade-in">
          <div class="bg-white rounded-3xl border border-slate-200/90 shadow-sm overflow-hidden">
            <div class="p-6 border-b border-slate-200/80 bg-slate-50/50 flex flex-col lg:flex-row lg:items-center justify-between gap-4">
              <div class="relative w-full max-w-md">
                <i data-lucide="search" class="w-4 h-4 absolute left-3.5 top-1/2 -translate-y-1/2 text-slate-400"></i>
                <input type="text" id="romoOrdoSearchInput" placeholder="Cari Romo Ordo, nama, kota, email, ordo..." value="${state.romoOrdoSearch}"
                  oninput="state.romoOrdoSearch = this.value; renderApp();"
                  class="w-full pl-10 pr-9 py-2.5 bg-white border border-slate-200 rounded-xl text-xs font-bold text-slate-900 focus:outline-none focus:ring-2 focus:ring-slate-400 shadow-sm transition" />
              </div>

              <div class="flex flex-wrap items-center gap-3">
                <div class="relative">
                  <select onchange="state.romoOrdoFilterOrdo = this.value; renderApp();"
                    class="pl-3.5 pr-8 py-2.5 bg-white border border-slate-200 rounded-xl text-xs font-bold text-slate-800 focus:outline-none focus:ring-2 focus:ring-slate-400 shadow-sm max-w-[210px] truncate">
                    <option value="">Semua Ordo Religius</option>
                    ${ordoList.map(o => `
                      <option value="${o.id || o.name}" ${String(state.romoOrdoFilterOrdo) === String(o.id || o.name) ? 'selected' : ''}>${o.name}</option>
                    `).join('')}
                  </select>
                </div>

                <div class="relative">
                  <select onchange="state.romoOrdoFilterPosition = this.value; renderApp();"
                    class="pl-3.5 pr-8 py-2.5 bg-white border border-slate-200 rounded-xl text-xs font-bold text-slate-800 focus:outline-none focus:ring-2 focus:ring-slate-400 shadow-sm">
                    <option value="">Semua Jabatan Ordo</option>
                    ${positionList.map(pos => `
                      <option value="${pos}" ${state.romoOrdoFilterPosition === pos ? 'selected' : ''}>${pos}</option>
                    `).join('')}
                  </select>
                </div>

                ${hasFilter ? `
                  <button onclick="state.romoOrdoSearch = ''; state.romoOrdoFilterOrdo = ''; state.romoOrdoFilterPosition = ''; renderApp();"
                    class="inline-flex items-center space-x-1 px-3 py-2 rounded-xl bg-slate-100 hover:bg-slate-200 text-slate-700 text-xs font-bold transition">
                    <i data-lucide="rotate-ccw" class="w-3.5 h-3.5 text-slate-500"></i>
                    <span>Reset</span>
                  </button>
                ` : ''}

                <span class="px-3.5 py-1.5 rounded-full bg-slate-100 text-slate-700 border border-slate-200 text-xs font-bold whitespace-nowrap">
                  ${list.length} Romo Ordo
                </span>
              </div>
            </div>

            <div class="overflow-x-auto">
              <table class="w-full text-left text-xs">
                <thead class="bg-slate-50 text-slate-600 font-bold border-b border-slate-200 tracking-wider uppercase text-[10.5px]">
                  <tr>
                    <th class="px-6 py-4">NAMA ROMO</th>
                    <th class="px-6 py-4">KOTA / DOMISILI</th>
                    <th class="px-6 py-4">ORDO RELIGIUS</th>
                    <th class="px-6 py-4">JABATAN STRUKTUR</th>
                    <th class="px-6 py-4">NO. WHATSAPP</th>
                    <th class="px-6 py-4 text-right">AKSI</th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-slate-100 font-medium text-slate-700">
                  ${list.length === 0 ? `
                    <tr>
                      <td colspan="6" class="text-center py-16 text-slate-400 space-y-3">
                        <div class="w-14 h-14 rounded-2xl bg-slate-50 border border-slate-200 flex items-center justify-center mx-auto text-slate-400">
                          <i data-lucide="cross" class="w-7 h-7"></i>
                        </div>
                        <p class="font-bold text-slate-700 text-sm">Tidak ada Romo Ordo yang sesuai filter</p>
                      </td>
                    </tr>
                  ` : list.map(u => `
                    <tr class="hover:bg-slate-50/80 transition duration-150 group">
                      <td class="px-6 py-4">
                        <p class="font-bold text-slate-900 text-sm tracking-tight">${u.full_name || 'Romo Ordo'}</p>
                        <p class="text-[11px] text-slate-400 font-medium truncate max-w-xs mt-0.5">${u.email || '-'}</p>
                      </td>
                      <td class="px-6 py-4">
                        <div class="inline-flex items-center space-x-1.5 px-3 py-1 rounded-xl bg-slate-100 text-slate-700 font-bold border border-slate-200 text-xs shadow-sm">
                          <i data-lucide="map-pin" class="w-3.5 h-3.5 text-slate-400"></i>
                          <span class="truncate max-w-[170px]">${u.kota_name || u.address || '-'}</span>
                        </div>
                      </td>
                      <td class="px-6 py-4">
                        <span class="inline-flex items-center px-3 py-1.5 rounded-xl bg-slate-100 text-slate-800 border border-slate-200 font-bold text-xs shadow-sm">
                          <span>${u.ordo_name || 'Ordo Religius'}</span>
                        </span>
                      </td>
                      <td class="px-6 py-4">
                        ${getUserPositionBadge(u.romo_position || 'Romo Ordo', 'ROMO_ORDO')}
                      </td>
                      <td class="px-6 py-4 font-bold text-slate-800">
                        <span class="inline-flex items-center space-x-1.5 text-xs">
                          <i data-lucide="phone" class="w-3.5 h-3.5 text-slate-400"></i>
                          <span>${u.phone_number}</span>
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
        </div>
      `;
    }

    // ── Tab: Approvals ──
