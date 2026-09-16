// ── Master Data Main View ──
    function renderMasterTab() {
      const sub = state.masterSubTab || 'paroki';
      const search = (state.masterSearch || '').toLowerCase().trim();
      const list = state.masterDataList || [];

      // Filtered items based on search and filters
      const filtered = list.filter(item => {
        if (search) {
          const matchName = item.name && item.name.toLowerCase().includes(search);
          const matchCode = item.code && item.code.toLowerCase().includes(search);
          const matchAddress = item.address && item.address.toLowerCase().includes(search);
          const matchKeuskupan = item.keuskupan_name && item.keuskupan_name.toLowerCase().includes(search);
          const matchParoki = item.paroki_name && item.paroki_name.toLowerCase().includes(search);
          const matchWilayah = item.wilayah_name && item.wilayah_name.toLowerCase().includes(search);
          const matchDesc = item.description && item.description.toLowerCase().includes(search);
          if (!matchName && !matchCode && !matchAddress && !matchKeuskupan && !matchParoki && !matchWilayah && !matchDesc) {
            return false;
          }
        }
        return true;
      });

      const getEntityLabel = (s) => {
        if (s === 'keuskupan') return 'Keuskupan';
        if (s === 'paroki') return 'Paroki';
        if (s === 'wilayah') return 'Wilayah';
        if (s === 'lingkungan') return 'Lingkungan';
        if (s === 'ordo') return 'Ordo / Kongregasi';
        if (s === 'services') return 'Kategori Pelayanan';
        if (s === 'roles') return 'Jenis User / Peran Pengguna';
        if (s === 'positions') return 'Jabatan & Struktur Pengurus / Romo';
        return s;
      };

      const getEntityDescription = (s) => {
        if (s === 'keuskupan') return 'Hierarki Keuskupan Agung & Keuskupan Sufragan se-Indonesia';
        if (s === 'paroki') return 'Daftar Gereja Paroki Katolik terhubung dengan Keuskupan induk';
        if (s === 'wilayah') return 'Struktur Wilayah Rohani / Teritorial gereja di bawah naungan Paroki';
        if (s === 'lingkungan') return 'Komunitas basis Umat Katolik di tingkat RT/RW Lingkungan';
        if (s === 'ordo') return 'Daftar Ordo & Kongregasi Religius (Imam & Biarawan On-Demand)';
        if (s === 'services') return 'Katalog Sakramen, Misa, dan Layanan Pastoral Gereja';
        if (s === 'roles') return 'Hak akses dan peran akun pengguna mobile & web portal';
        if (s === 'positions') return 'Struktur hierarki jabatan resmi (Ketua Lingkungan, Kepala Romo, Sekretaris)';
        return 'Pengelolaan data master gereja terintegrasi PostgreSQL';
      };

      const getEntityIcon = (s) => {
        if (s === 'keuskupan') return 'landmark';
        if (s === 'paroki') return 'church';
        if (s === 'wilayah') return 'map-pin';
        if (s === 'lingkungan') return 'home';
        if (s === 'ordo') return 'cross';
        if (s === 'services') return 'clipboard-list';
        if (s === 'roles') return 'shield-check';
        if (s === 'positions') return 'award';
        return 'database';
      };

      return `
        <div class="space-y-6 animate-fade-in">
          <!-- Sub-Tab Navigation Bar -->
          <div class="bg-white/95 backdrop-blur-md rounded-2xl p-2 shadow-xs border border-slate-200/90 flex flex-wrap gap-2">
            ${[
              { id: 'keuskupan', icon: 'landmark', label: 'Keuskupan', count: state.keuskupan?.length, color: 'text-blue-600' },
              { id: 'paroki', icon: 'church', label: 'Paroki', count: state.paroki?.length, color: 'text-emerald-600' },
              { id: 'wilayah', icon: 'map-pin', label: 'Wilayah', color: 'text-indigo-600' },
              { id: 'lingkungan', icon: 'home', label: 'Lingkungan', color: 'text-cyan-600' },
              { id: 'ordo', icon: 'cross', label: 'Ordo / Kongregasi', count: state.ordo?.length, color: 'text-purple-600' },
              { id: 'services', icon: 'clipboard-list', label: 'Kategori Pelayanan', count: state.serviceCategories?.length, color: 'text-amber-600' },
              { id: 'roles', icon: 'shield-check', label: 'Jenis User / Role', count: state.roles?.length, color: 'text-rose-600' },
              { id: 'positions', icon: 'award', label: 'Jabatan & Struktur', count: state.positions?.length, color: 'text-amber-600' }
            ].map(tab => {
              const active = sub === tab.id;
              return `
                <button onclick="setMasterSubTab('${tab.id}')"
                  class="flex items-center space-x-2.5 px-4 py-2.5 rounded-xl font-extrabold text-xs transition-all ${
                    active 
                      ? 'bg-gradient-to-r from-blue-950 via-slate-900 to-indigo-950 text-white shadow-md shadow-blue-950/25 ring-1 ring-white/15 scale-[1.02]' 
                      : 'text-slate-600 hover:bg-slate-100/90 hover:text-slate-950 hover:scale-[1.01]'
                  }">
                  <i data-lucide="${tab.icon}" class="w-4 h-4 ${active ? 'text-amber-400' : tab.color}"></i>
                  <span class="tracking-wide">${tab.label}</span>
                  ${tab.count !== undefined && tab.count > 0 ? `
                    <span class="px-2 py-0.5 rounded-full text-[10px] font-black ${
                      active 
                        ? 'bg-amber-400 text-slate-950 shadow-2xs' 
                        : 'bg-slate-100 text-slate-700 border border-slate-200'
                    }">
                      ${tab.count}
                    </span>
                  ` : ''}
                </button>
              `;
            }).join('')}
          </div>

          <!-- Main Table Card (Ultra-Beautified UI Container) -->
          <div class="bg-white rounded-3xl shadow-xl shadow-slate-200/50 border border-slate-200/90 overflow-hidden">
            
            <!-- Premium Header Banner Toolbar -->
            <div class="bg-gradient-to-r from-slate-950 via-blue-950 to-indigo-950 text-white p-6 lg:p-7 relative overflow-hidden border-b border-blue-900/40">
              <!-- Ambient Background Glows -->
              <div class="absolute -right-16 -top-16 w-64 h-64 bg-amber-500/15 rounded-full blur-3xl pointer-events-none"></div>
              <div class="absolute right-1/3 -bottom-20 w-48 h-48 bg-blue-500/10 rounded-full blur-2xl pointer-events-none"></div>

              <div class="relative z-10 flex flex-col lg:flex-row lg:items-center justify-between gap-5">
                <!-- Left Title & Counter -->
                <div class="flex items-center space-x-4">
                  <div class="w-14 h-14 rounded-2xl bg-gradient-to-br from-amber-400 via-amber-500 to-amber-600 text-slate-950 flex items-center justify-center shadow-lg shadow-amber-500/25 ring-2 ring-white/20 flex-shrink-0">
                    <i data-lucide="${getEntityIcon(sub)}" class="w-7 h-7"></i>
                  </div>
                  <div>
                    <div class="flex items-center space-x-2.5 flex-wrap">
                      <span class="text-[10.5px] font-black uppercase tracking-wider text-amber-400/90 flex items-center">
                        <i data-lucide="database" class="w-3 h-3 mr-1"></i> MASTER DATA
                      </span>
                      <span class="text-slate-500 font-bold">•</span>
                      <h3 class="text-xl font-black text-white tracking-tight">${getEntityLabel(sub)}</h3>
                      <span class="px-3 py-0.5 rounded-full bg-white/10 text-amber-300 border border-white/15 text-xs font-black backdrop-blur-md shadow-xs">
                        ${filtered.length} Data Tersedia
                      </span>
                    </div>
                    <p class="text-xs text-slate-300/90 font-medium mt-1 flex items-center space-x-1.5">
                      <span>${getEntityDescription(sub)}</span>
                    </p>
                  </div>
                </div>

                <!-- Right Search, Filters & Action Controls -->
                <div class="flex flex-wrap items-center gap-3">
                  <!-- Search Input with Glass Styling -->
                  <div class="relative">
                    <i data-lucide="search" class="w-4 h-4 absolute left-3.5 top-1/2 -translate-y-1/2 text-slate-400 pointer-events-none"></i>
                    <input type="text" id="masterSearchInput" value="${state.masterSearch || ''}" oninput="state.masterSearch = this.value; renderApp();"
                      placeholder="Cari ${getEntityLabel(sub)}..."
                      class="pl-10 pr-9 py-2.5 bg-white/10 hover:bg-white/15 focus:bg-white text-white focus:text-slate-900 border border-white/20 focus:border-amber-400 rounded-2xl text-xs font-bold w-full sm:w-60 lg:w-72 shadow-inner placeholder:text-slate-400 transition-all backdrop-blur-md focus:outline-none focus:ring-2 focus:ring-amber-400/50" />
                    ${state.masterSearch ? `
                      <button onclick="state.masterSearch = ''; renderApp();" class="absolute right-3 top-1/2 -translate-y-1/2 text-slate-400 hover:text-white p-0.5 transition" title="Hapus Pencarian">
                        <i data-lucide="x" class="w-3.5 h-3.5"></i>
                      </button>
                    ` : ''}
                  </div>

                  <!-- Contextual Filter: Keuskupan for Paroki -->
                  ${sub === 'paroki' ? `
                    <div class="relative">
                      <select onchange="state.masterFilterKeuskupanId = this.value; loadMasterData('paroki');"
                        class="pl-3.5 pr-8 py-2.5 bg-white/10 hover:bg-white/20 text-white border border-white/20 rounded-2xl text-xs font-bold focus:outline-none focus:ring-2 focus:ring-amber-400 shadow-xs backdrop-blur-md transition">
                        <option value="" class="text-slate-900">Semua Keuskupan (${state.keuskupan.length})</option>
                        ${state.keuskupan.map(k => `
                          <option value="${k.id}" ${String(state.masterFilterKeuskupanId) === String(k.id) ? 'selected' : ''} class="text-slate-900">${k.name}</option>
                        `).join('')}
                      </select>
                    </div>
                  ` : ''}

                  <!-- Contextual Filter: Paroki for Wilayah -->
                  ${sub === 'wilayah' ? `
                    <div class="relative">
                      <select onchange="state.masterFilterParokiId = this.value; loadMasterData('wilayah');"
                        class="pl-3.5 pr-8 py-2.5 bg-white/10 hover:bg-white/20 text-white border border-white/20 rounded-2xl text-xs font-bold focus:outline-none focus:ring-2 focus:ring-amber-400 shadow-xs max-w-xs truncate backdrop-blur-md transition">
                        <option value="" class="text-slate-900">Semua Paroki (${state.paroki.length})</option>
                        ${state.paroki.map(p => `
                          <option value="${p.id}" ${String(state.masterFilterParokiId) === String(p.id) ? 'selected' : ''} class="text-slate-900">${p.name}</option>
                        `).join('')}
                      </select>
                    </div>
                  ` : ''}

                  <!-- Contextual Filter: Wilayah for Lingkungan -->
                  ${sub === 'lingkungan' ? `
                    <div class="relative">
                      <select onchange="state.masterFilterWilayahId = this.value; loadMasterData('lingkungan');"
                        class="pl-3.5 pr-8 py-2.5 bg-white/10 hover:bg-white/20 text-white border border-white/20 rounded-2xl text-xs font-bold focus:outline-none focus:ring-2 focus:ring-amber-400 shadow-xs max-w-xs truncate backdrop-blur-md transition">
                        <option value="" class="text-slate-900">Semua Wilayah</option>
                        ${(state.modalWilayahList || []).map(w => `
                          <option value="${w.id}" ${String(state.masterFilterWilayahId) === String(w.id) ? 'selected' : ''} class="text-slate-900">${w.name}</option>
                        `).join('')}
                      </select>
                    </div>
                  ` : ''}

                  <!-- Add Primary Action Button -->
                  <button onclick="openCreateMasterModal('${sub}')"
                    class="px-4.5 py-2.5 rounded-xl bg-gradient-to-r from-amber-400 via-amber-500 to-amber-600 hover:from-amber-500 hover:to-amber-600 text-slate-950 font-bold text-xs shadow-md shadow-amber-500/25 flex items-center space-x-2 transition-all transform hover:-translate-y-0.5 active:translate-y-0 flex-shrink-0 cursor-pointer">
                    <i data-lucide="plus" class="w-4 h-4 text-slate-950"></i>
                    <span>Tambah ${getEntityLabel(sub)}</span>
                  </button>
                </div>
              </div>
            </div>

            <!-- Table View -->
            ${state.isMasterLoading ? `
              <div class="p-20 text-center text-slate-500 space-y-4">
                <div class="w-12 h-12 rounded-full border-4 border-amber-500 border-t-transparent animate-spin mx-auto"></div>
                <div>
                  <p class="text-sm font-extrabold text-slate-800">Menyinkronkan Data ${getEntityLabel(sub)}...</p>
                  <p class="text-xs text-slate-400 mt-1">Mengambil data terbaru langsung dari database PostgreSQL CATU v2</p>
                </div>
              </div>
            ` : filtered.length === 0 ? `
              <div class="p-20 text-center text-slate-400 space-y-4">
                <div class="w-20 h-20 rounded-3xl bg-slate-50 border border-slate-200 text-slate-400 flex items-center justify-center mx-auto shadow-inner">
                  <i data-lucide="folder-search" class="w-10 h-10 text-amber-500/70"></i>
                </div>
                <div class="max-w-md mx-auto">
                  <p class="text-base font-extrabold text-slate-800">Tidak ada data ${getEntityLabel(sub)} yang cocok</p>
                  <p class="text-xs text-slate-500 mt-1">Gunakan kata kunci lain atau klik tombol di bawah untuk membuat data baru di database.</p>
                </div>
                <button onclick="openCreateMasterModal('${sub}')" 
                  class="inline-flex items-center space-x-2 px-5 py-2.5 rounded-xl bg-amber-500 hover:bg-amber-600 text-white text-xs font-bold shadow-md shadow-amber-500/25 transition transform hover:-translate-y-0.5">
                  <i data-lucide="plus" class="w-4 h-4"></i>
                  <span>Tambah ${getEntityLabel(sub)} Baru</span>
                </button>
              </div>
            ` : `
              <div class="overflow-x-auto custom-scrollbar">
                <table class="w-full text-left border-collapse text-xs">
                  <thead>
                    <tr class="bg-gradient-to-r from-slate-100/90 via-slate-50 to-slate-100/80 border-b border-slate-200 text-slate-600 font-black tracking-wider uppercase text-[10.5px]">
                      <th class="py-4 px-6 w-20 text-center">ID</th>
                      ${renderMasterTableHeaders(sub)}
                      <th class="py-4 px-6 text-center w-56">AKSI & KELOLA</th>
                    </tr>
                  </thead>
                  <tbody class="divide-y divide-slate-100">
                    ${filtered.map((item, idx) => renderMasterTableRow(sub, item, idx)).join('')}
                  </tbody>
                </table>
              </div>

              <!-- Footer Statistics Bar -->
              <div class="p-5 bg-gradient-to-r from-slate-50 via-white to-slate-50 border-t border-slate-200/80 flex flex-col sm:flex-row items-center justify-between gap-3 text-xs font-semibold text-slate-500">
                <div class="flex items-center space-x-2">
                  <span class="w-2 h-2 rounded-full bg-emerald-500"></span>
                  <p>Menampilkan <span class="font-extrabold text-slate-900">${filtered.length}</span> entri data ${getEntityLabel(sub)}</p>
                </div>
                <div class="flex items-center space-x-2.5">
                  <span class="inline-flex items-center space-x-1.5 px-3 py-1 rounded-full bg-emerald-50 text-emerald-800 border border-emerald-200 text-[11px] font-extrabold shadow-2xs">
                    <span class="w-1.5 h-1.5 rounded-full bg-emerald-500 animate-pulse"></span>
                    <span>PostgreSQL Live Synchronized</span>
                  </span>
                </div>
              </div>
            `}
          </div>
        </div>
      `;
    }
