// ── Master Data Main View ──
    function renderMasterTab() {
      const sub = state.masterSubTab || 'paroki';
      const search = (state.masterSearch || '').toLowerCase().trim();
      let list = state.masterDataList || [];

      // Sort newest records first so newly added data is immediately visible at top of grid
      list = [...list].sort((a, b) => Number(b.id || 0) - Number(a.id || 0));

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
              { id: 'keuskupan', icon: 'landmark', label: 'Keuskupan', count: state.keuskupan?.length },
              { id: 'paroki', icon: 'church', label: 'Paroki', count: state.paroki?.length },
              { id: 'wilayah', icon: 'map-pin', label: 'Wilayah' },
              { id: 'lingkungan', icon: 'home', label: 'Lingkungan' },
              { id: 'ordo', icon: 'cross', label: 'Ordo / Kongregasi', count: state.ordo?.length },
              { id: 'services', icon: 'clipboard-list', label: 'Kategori Pelayanan', count: state.serviceCategories?.length },
              { id: 'roles', icon: 'shield-check', label: 'Jenis User / Role', count: state.roles?.length },
              { id: 'positions', icon: 'award', label: 'Jabatan & Struktur', count: state.positions?.length }
            ].map(tab => {
              const active = sub === tab.id;
              return `
                <button onclick="setMasterSubTab('${tab.id}')"
                  class="flex items-center space-x-2.5 px-4 py-2.5 rounded-xl font-bold text-xs transition-all ${
                    active 
                      ? 'bg-blue-950 text-white shadow-xs' 
                      : 'text-slate-600 hover:bg-slate-100 hover:text-blue-950'
                  }">
                  <i data-lucide="${tab.icon}" class="w-4 h-4 ${active ? 'text-blue-400' : 'text-slate-400'}"></i>
                  <span class="tracking-wide">${tab.label}</span>
                  ${tab.count !== undefined && tab.count > 0 ? `
                    <span class="px-2 py-0.5 rounded-full text-[10px] font-bold ${
                      active 
                        ? 'bg-blue-600 text-white' 
                        : 'bg-slate-100 text-slate-700 border border-slate-200'
                    }">
                      ${tab.count}
                    </span>
                  ` : ''}
                </button>
              `;
            }).join('')}
          </div>

          <!-- Main Table Card -->
          <div class="bg-white rounded-2xl border border-slate-200/90 shadow-sm overflow-hidden">
            
            <!-- Header Toolbar -->
            <div class="p-6 border-b border-slate-200/80 bg-slate-50/50 flex flex-col lg:flex-row lg:items-center justify-between gap-4">
              <!-- Search Input -->
              <div class="relative w-full max-w-md">
                <i data-lucide="search" class="w-4 h-4 absolute left-3.5 top-1/2 -translate-y-1/2 text-slate-400"></i>
                <input type="text" id="masterSearchInput" value="${state.masterSearch || ''}" oninput="state.masterSearch = this.value; renderApp();"
                  placeholder="Cari ${getEntityLabel(sub)}..."
                  class="w-full pl-10 pr-9 py-2.5 bg-white border border-slate-200 rounded-xl text-xs font-bold text-slate-900 focus:outline-none focus:ring-2 focus:ring-slate-400 shadow-sm transition" />
                ${state.masterSearch ? `
                  <button onclick="state.masterSearch = ''; renderApp();" class="absolute right-3 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-600 p-0.5 transition" title="Hapus Pencarian">
                    <i data-lucide="x" class="w-3.5 h-3.5"></i>
                  </button>
                ` : ''}
              </div>

              <!-- Filters & Action Controls -->
              <div class="flex flex-wrap items-center gap-3">

                <span class="px-3.5 py-1.5 rounded-full bg-slate-100 text-slate-700 border border-slate-200 text-xs font-bold whitespace-nowrap">
                  ${filtered.length} Data
                </span>

                <button onclick="openCreateMasterModal('${sub}')"
                  class="inline-flex items-center space-x-1.5 px-4 py-2 rounded-xl bg-blue-950 hover:bg-blue-900 text-white text-xs font-bold shadow-xs transition">
                  <i data-lucide="plus" class="w-4 h-4"></i>
                  <span>Tambah ${getEntityLabel(sub)}</span>
                </button>
              </div>
            </div>

            <!-- Table View -->
            ${state.isMasterLoading ? `
              <div class="p-16 text-center text-slate-500 space-y-3">
                <div class="w-10 h-10 rounded-full border-4 border-blue-600 border-t-transparent animate-spin mx-auto"></div>
                <p class="text-xs font-bold text-slate-700">Memuat data ${getEntityLabel(sub)}...</p>
              </div>
            ` : filtered.length === 0 ? `
              <div class="p-16 text-center text-slate-400 space-y-3">
                <div class="w-16 h-16 rounded-2xl bg-slate-50 border border-slate-200 text-slate-400 flex items-center justify-center mx-auto">
                  <i data-lucide="folder-search" class="w-8 h-8 text-blue-600"></i>
                </div>
                <div class="max-w-md mx-auto">
                  <p class="text-sm font-bold text-slate-800">Tidak ada data ${getEntityLabel(sub)} yang cocok</p>
                  <p class="text-xs text-slate-500 mt-1">Gunakan kata kunci pencarian lain atau tambahkan data baru.</p>
                </div>
                <button onclick="openCreateMasterModal('${sub}')" 
                  class="inline-flex items-center space-x-2 px-4 py-2 rounded-xl bg-blue-950 hover:bg-blue-900 text-white text-xs font-bold shadow-xs transition">
                  <i data-lucide="plus" class="w-4 h-4"></i>
                  <span>Tambah ${getEntityLabel(sub)} Baru</span>
                </button>
              </div>
            ` : `
              <div class="overflow-x-auto">
                <table class="w-full text-left text-xs">
                  <thead class="bg-slate-50 text-slate-600 font-bold border-b border-slate-200 tracking-wider uppercase text-[10.5px]">
                    <tr>
                      ${renderMasterTableHeaders(sub)}
                      <th class="py-4 px-6 text-right w-56">AKSI</th>
                    </tr>
                  </thead>
                  <tbody class="divide-y divide-slate-100 font-medium text-slate-700">
                    ${filtered.map((item, idx) => renderMasterTableRow(sub, item, idx)).join('')}
                  </tbody>
                </table>
              </div>
            `}
          </div>
        </div>
      `;
    }
