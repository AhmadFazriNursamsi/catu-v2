// ── Master Data Table Header & Row Generators ──
    function renderMasterTableHeaders(sub) {
      if (sub === 'keuskupan') {
        return `
          <th class="py-4 px-6">NAMA KEUSKUPAN</th>
          <th class="py-4 px-6">TOTAL PAROKI</th>
          <th class="py-4 px-6">TANGGAL TERDAFTAR</th>
        `;
      } else if (sub === 'paroki') {
        return `
          <th class="py-4 px-6">NAMA PAROKI</th>
          <th class="py-4 px-6">KEUSKUPAN INDUK</th>
          <th class="py-4 px-6">TOTAL WILAYAH</th>
        `;
      } else if (sub === 'wilayah') {
        return `
          <th class="py-4 px-6">NAMA WILAYAH</th>
          <th class="py-4 px-6">PAROKI INDUK</th>
          <th class="py-4 px-6">KEUSKUPAN</th>
          <th class="py-4 px-6">TOTAL LINGKUNGAN</th>
        `;
      } else if (sub === 'lingkungan') {
        return `
          <th class="py-4 px-6">NAMA LINGKUNGAN</th>
          <th class="py-4 px-6">WILAYAH INDUK</th>
          <th class="py-4 px-6">PAROKI</th>
          <th class="py-4 px-6">TOTAL UMAT</th>
        `;
      } else if (sub === 'ordo') {
        return `
          <th class="py-4 px-6">NAMA ORDO / KONGREGASI</th>
          <th class="py-4 px-6">KODE</th>
          <th class="py-4 px-6">TOTAL ROMO</th>
          <th class="py-4 px-6">ALAMAT MARKAS</th>
        `;
      } else if (sub === 'services') {
        return `
          <th class="py-4 px-6">NAMA SAKRAMEN / PELAYANAN</th>
          <th class="py-4 px-6">DESKRIPSI</th>
          <th class="py-4 px-6 text-center">URGENT DEFAULT</th>
          <th class="py-4 px-6 text-center">STATUS AKTIF</th>
          <th class="py-4 px-6">TOTAL ORDER</th>
        `;
      } else if (sub === 'roles') {
        return `
          <th class="py-4 px-6">KODE ROLE</th>
          <th class="py-4 px-6">NAMA PERAN / JENIS USER</th>
          <th class="py-4 px-6">TOTAL PENGGUNA TERHUBUNG</th>
          <th class="py-4 px-6">TIPE AKSES</th>
        `;
      } else if (sub === 'positions') {
        return `
          <th class="py-4 px-6">KODE JABATAN</th>
          <th class="py-4 px-6">NAMA JABATAN</th>
          <th class="py-4 px-6">KATEGORI STRUKTUR</th>
          <th class="py-4 px-6">STATUS PIMPINAN</th>
          <th class="py-4 px-6">TOTAL PEJABAT AKTIF</th>
        `;
      } else if (sub === 'provinsi') {
        return `
          <th class="py-4 px-6">NAMA PROVINSI</th>
          <th class="py-4 px-6">TOTAL KABUPATEN / KOTA</th>
          <th class="py-4 px-6">STATUS</th>
        `;
      } else if (sub === 'kabupaten_kota') {
        return `
          <th class="py-4 px-6">NAMA KABUPATEN / KOTA</th>
          <th class="py-4 px-6">JENIS / TIPE</th>
          <th class="py-4 px-6">PROVINSI INDUK</th>
          <th class="py-4 px-6">TOTAL PENGGUNA TERHUBUNG</th>
        `;
      }
      return '';
    }

    function renderMasterTableRow(sub, item, idx) {
      const escapedItem = JSON.stringify(item).replace(/'/g, "&#39;");
      const isNew = state.lastCreatedMasterId && String(state.lastCreatedMasterId) === String(item.id);
      return `
        <tr class="${isNew ? 'bg-blue-50/70' : 'hover:bg-slate-50/80'} transition duration-150 group">
          ${renderMasterTableColumns(sub, item)}
          <td class="py-4 px-6 text-right">
            <div class="inline-flex items-center justify-end space-x-2">
              ${sub === 'keuskupan' ? `
                <button onclick='openCreateMasterModal("paroki", { keuskupan_id: ${item.id} })'
                  class="inline-flex items-center space-x-1 text-xs font-semibold text-blue-700 hover:text-blue-900 transition py-1 px-1.5 rounded hover:bg-blue-50" title="Tambah Paroki Baru di Keuskupan Ini">
                  <i data-lucide="plus" class="w-3.5 h-3.5 text-blue-600"></i>
                  <span>Paroki</span>
                </button>
                <span class="text-slate-300">·</span>
              ` : ''}
              ${sub === 'paroki' ? `
                <button onclick='openCreateMasterModal("wilayah", { keuskupan_id: ${escapeHtml(item.keuskupan_id || 'null')}, paroki_id: ${item.id} })'
                  class="inline-flex items-center space-x-1 text-xs font-semibold text-blue-700 hover:text-blue-900 transition py-1 px-1.5 rounded hover:bg-blue-50" title="Tambah Wilayah Baru di Paroki Ini">
                  <i data-lucide="plus" class="w-3.5 h-3.5 text-blue-600"></i>
                  <span>Wilayah</span>
                </button>
                <span class="text-slate-300">·</span>
              ` : ''}
              ${sub === 'wilayah' ? `
                <button onclick='openCreateMasterModal("lingkungan", { paroki_id: ${escapeHtml(item.paroki_id || 'null')}, wilayah_id: ${item.id} })'
                  class="inline-flex items-center space-x-1 text-xs font-semibold text-blue-700 hover:text-blue-900 transition py-1 px-1.5 rounded hover:bg-blue-50" title="Tambah Lingkungan Baru di Wilayah Ini">
                  <i data-lucide="plus" class="w-3.5 h-3.5 text-blue-600"></i>
                  <span>Lingkungan</span>
                </button>
                <span class="text-slate-300">·</span>
              ` : ''}
              ${sub === 'provinsi' ? `
                <button onclick='openCreateMasterModal("kabupaten_kota", { provinsi_id: ${item.id} })'
                  class="inline-flex items-center space-x-1 text-xs font-semibold text-blue-700 hover:text-blue-900 transition py-1 px-1.5 rounded hover:bg-blue-50" title="Tambah Kab/Kota di Provinsi Ini">
                  <i data-lucide="plus" class="w-3.5 h-3.5 text-blue-600"></i>
                  <span>Kab/Kota</span>
                </button>
                <span class="text-slate-300">·</span>
              ` : ''}

              ${(['services', 'roles', 'positions'].includes(sub) && (typeof isSuperAdminUser === 'function' && !isSuperAdminUser())) ? `
                <span class="inline-flex items-center space-x-1 px-2 py-0.5 rounded text-[10.5px] font-semibold text-slate-500 bg-slate-100 border border-slate-200">
                  <i data-lucide="lock" class="w-3 h-3 text-slate-400"></i>
                  <span>Read-only</span>
                </span>
              ` : `
                <button onclick='openEditMasterModal("${sub}", ${escapedItem})'
                  class="inline-flex items-center space-x-1 text-xs font-semibold text-slate-600 hover:text-slate-900 transition py-1 px-1.5 rounded hover:bg-slate-100" title="Edit Data">
                  <i data-lucide="edit-3" class="w-3.5 h-3.5 text-slate-500"></i>
                  <span>Edit</span>
                </button>
                <span class="text-slate-300">·</span>
                <button onclick='confirmDeleteMaster(${jsArg(sub)}, ${Number(item.id)}, ${jsArg(item.name || '')})'
                  class="inline-flex items-center space-x-1 text-xs font-semibold text-rose-600 hover:text-rose-800 transition py-1 px-1.5 rounded hover:bg-rose-50" title="Hapus Data">
                  <i data-lucide="trash-2" class="w-3.5 h-3.5 text-rose-500"></i>
                  <span>Hapus</span>
                </button>
              `}
            </div>
          </td>
        </tr>
      `;
    }

    function setMasterPage(newPage) {
      state.masterPage = newPage;
      renderApp();
      const table = document.getElementById('master-table-card');
      if (table) table.scrollIntoView({ behavior: 'smooth', block: 'start' });
    }

    function changeMasterPageSize(newSize) {
      state.masterPageSize = newSize;
      state.masterPage = 1;
      renderApp();
    }

    function renderMasterPagination(total, page, pageSize, totalPages) {
      if (total <= 0) return '';
      const start = (page - 1) * pageSize + 1;
      const end = Math.min(total, page * pageSize);

      return `
        <div class="p-3.5 sm:p-5 border-t border-slate-200/90 bg-slate-50/70 flex flex-col md:flex-row items-center justify-between gap-3 text-xs text-slate-600 font-medium">
          <!-- Info & Page Size -->
          <div class="flex flex-wrap items-center gap-2 sm:gap-4 w-full md:w-auto justify-between md:justify-start">
            <div>
              Menampilkan <strong class="text-slate-900 font-bold">${start}</strong> - <strong class="text-slate-900 font-bold">${end}</strong> dari <strong class="text-slate-900 font-bold">${total}</strong> data
            </div>
            <div class="flex items-center space-x-1.5 text-slate-500">
              <span>Baris:</span>
              <select onchange="changeMasterPageSize(Number(this.value))"
                class="py-1 px-2 bg-white border border-slate-200 rounded-lg text-xs font-bold text-slate-800 focus:outline-none focus:ring-1 focus:ring-slate-400 cursor-pointer shadow-2xs">
                <option value="15" ${pageSize === 15 ? 'selected' : ''}>15</option>
                <option value="25" ${pageSize === 25 ? 'selected' : ''}>25</option>
                <option value="50" ${pageSize === 50 ? 'selected' : ''}>50</option>
                <option value="100" ${pageSize === 100 ? 'selected' : ''}>100</option>
              </select>
            </div>
          </div>

          <!-- Pagination Buttons -->
          <div class="flex items-center space-x-1 sm:space-x-1.5 w-full md:w-auto justify-center md:justify-end">
            <button type="button" onclick="setMasterPage(1)" ${page <= 1 ? 'disabled' : ''}
              class="p-1.5 sm:px-2.5 sm:py-1.5 rounded-lg border border-slate-200 bg-white hover:bg-slate-100 text-slate-700 font-bold disabled:opacity-40 disabled:cursor-not-allowed transition flex items-center space-x-1 shadow-2xs" title="Halaman Pertama">
              <i data-lucide="chevrons-left" class="w-3.5 h-3.5"></i>
              <span class="hidden sm:inline">Awal</span>
            </button>
            <button type="button" onclick="setMasterPage(${page - 1})" ${page <= 1 ? 'disabled' : ''}
              class="p-1.5 sm:px-2.5 sm:py-1.5 rounded-lg border border-slate-200 bg-white hover:bg-slate-100 text-slate-700 font-bold disabled:opacity-40 disabled:cursor-not-allowed transition flex items-center space-x-1 shadow-2xs" title="Halaman Sebelumnya">
              <i data-lucide="chevron-left" class="w-3.5 h-3.5"></i>
              <span class="hidden sm:inline">Sebelumnya</span>
            </button>

            <div class="px-2.5 py-1 text-xs font-bold text-slate-700 bg-white border border-slate-200 rounded-lg whitespace-nowrap shadow-2xs">
              Hal <span class="text-blue-950 font-black">${page}</span> / <span>${totalPages}</span>
            </div>

            <button type="button" onclick="setMasterPage(${page + 1})" ${page >= totalPages ? 'disabled' : ''}
              class="p-1.5 sm:px-2.5 sm:py-1.5 rounded-lg border border-slate-200 bg-white hover:bg-slate-100 text-slate-700 font-bold disabled:opacity-40 disabled:cursor-not-allowed transition flex items-center space-x-1 shadow-2xs" title="Halaman Berikutnya">
              <span class="hidden sm:inline">Berikutnya</span>
              <i data-lucide="chevron-right" class="w-3.5 h-3.5"></i>
            </button>
            <button type="button" onclick="setMasterPage(${totalPages})" ${page >= totalPages ? 'disabled' : ''}
              class="p-1.5 sm:px-2.5 sm:py-1.5 rounded-lg border border-slate-200 bg-white hover:bg-slate-100 text-slate-700 font-bold disabled:opacity-40 disabled:cursor-not-allowed transition flex items-center space-x-1 shadow-2xs" title="Halaman Terakhir">
              <span class="hidden sm:inline">Akhir</span>
              <i data-lucide="chevrons-right" class="w-3.5 h-3.5"></i>
            </button>
          </div>
        </div>
      `;
    }
