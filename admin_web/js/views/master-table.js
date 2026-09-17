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
                <button onclick='openCreateMasterModal("wilayah", { keuskupan_id: ${item.keuskupan_id || 'null'}, paroki_id: ${item.id} })'
                  class="inline-flex items-center space-x-1 text-xs font-semibold text-blue-700 hover:text-blue-900 transition py-1 px-1.5 rounded hover:bg-blue-50" title="Tambah Wilayah Baru di Paroki Ini">
                  <i data-lucide="plus" class="w-3.5 h-3.5 text-blue-600"></i>
                  <span>Wilayah</span>
                </button>
                <span class="text-slate-300">·</span>
              ` : ''}
              ${sub === 'wilayah' ? `
                <button onclick='openCreateMasterModal("lingkungan", { paroki_id: ${item.paroki_id || 'null'}, wilayah_id: ${item.id} })'
                  class="inline-flex items-center space-x-1 text-xs font-semibold text-blue-700 hover:text-blue-900 transition py-1 px-1.5 rounded hover:bg-blue-50" title="Tambah Lingkungan Baru di Wilayah Ini">
                  <i data-lucide="plus" class="w-3.5 h-3.5 text-blue-600"></i>
                  <span>Lingkungan</span>
                </button>
                <span class="text-slate-300">·</span>
              ` : ''}

              <button onclick='openEditMasterModal("${sub}", ${escapedItem})'
                class="inline-flex items-center space-x-1 text-xs font-semibold text-slate-600 hover:text-slate-900 transition py-1 px-1.5 rounded hover:bg-slate-100" title="Edit Data">
                <i data-lucide="edit-3" class="w-3.5 h-3.5 text-slate-500"></i>
                <span>Edit</span>
              </button>
              <span class="text-slate-300">·</span>
              <button onclick='confirmDeleteMaster("${sub}", ${item.id}, "${(item.name || '').replace(/"/g, '')}")'
                class="inline-flex items-center space-x-1 text-xs font-semibold text-rose-600 hover:text-rose-800 transition py-1 px-1.5 rounded hover:bg-rose-50" title="Hapus Data">
                <i data-lucide="trash-2" class="w-3.5 h-3.5 text-rose-500"></i>
                <span>Hapus</span>
              </button>
            </div>
          </td>
        </tr>
      `;
    }
