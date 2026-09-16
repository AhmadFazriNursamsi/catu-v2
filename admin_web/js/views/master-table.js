// ── Master Data Table Header & Row Generators ──
    function renderMasterTableHeaders(sub) {
      if (sub === 'keuskupan') {
        return `
          <th class="py-4 px-5">NAMA KEUSKUPAN</th>
          <th class="py-4 px-5">KODE</th>
          <th class="py-4 px-5 text-center">TOTAL PAROKI</th>
          <th class="py-4 px-5">TANGGAL TERDAFTAR</th>
        `;
      } else if (sub === 'paroki') {
        return `
          <th class="py-4 px-5">NAMA PAROKI</th>
          <th class="py-4 px-5">KEUSKUPAN INDUK</th>
          <th class="py-4 px-5 text-center">TOTAL WILAYAH</th>
          <th class="py-4 px-5">ALAMAT LENGKAP</th>
        `;
      } else if (sub === 'wilayah') {
        return `
          <th class="py-4 px-5">NAMA WILAYAH</th>
          <th class="py-4 px-5">PAROKI INDUK</th>
          <th class="py-4 px-5">KEUSKUPAN</th>
          <th class="py-4 px-5 text-center">TOTAL LINGKUNGAN</th>
        `;
      } else if (sub === 'lingkungan') {
        return `
          <th class="py-4 px-5">NAMA LINGKUNGAN</th>
          <th class="py-4 px-5">WILAYAH INDUK</th>
          <th class="py-4 px-5">PAROKI</th>
          <th class="py-4 px-5 text-center">TOTAL UMAT</th>
        `;
      } else if (sub === 'ordo') {
        return `
          <th class="py-4 px-5">NAMA ORDO / KONGREGASI</th>
          <th class="py-4 px-5">KODE</th>
          <th class="py-4 px-5 text-center">TOTAL ROMO</th>
          <th class="py-4 px-5">ALAMAT MARKAS</th>
        `;
      } else if (sub === 'services') {
        return `
          <th class="py-4 px-5">NAMA SAKRAMEN / PELAYANAN</th>
          <th class="py-4 px-5">DESKRIPSI</th>
          <th class="py-4 px-5 text-center">URGENT DEFAULT</th>
          <th class="py-4 px-5 text-center">STATUS AKTIF</th>
          <th class="py-4 px-5 text-center">TOTAL ORDER</th>
        `;
      } else if (sub === 'roles') {
        return `
          <th class="py-4 px-5">KODE ROLE</th>
          <th class="py-4 px-5">NAMA PERAN / JENIS USER</th>
          <th class="py-4 px-5 text-center">TOTAL PENGGUNA TERHUBUNG</th>
          <th class="py-4 px-5">TIPE AKSES</th>
        `;
      } else if (sub === 'positions') {
        return `
          <th class="py-4 px-5">KODE JABATAN</th>
          <th class="py-4 px-5">NAMA JABATAN</th>
          <th class="py-4 px-5">KATEGORI STRUKTUR</th>
          <th class="py-4 px-5 text-center">STATUS PIMPINAN</th>
          <th class="py-4 px-5 text-center">TOTAL PEJABAT AKTIF</th>
        `;
      }
      return '';
    }

    function renderMasterTableRow(sub, item, idx) {
      const escapedItem = JSON.stringify(item).replace(/'/g, "&#39;");
      return `
        <tr class="hover:bg-amber-50/30 transition duration-150 group border-b border-slate-100/90">
          <td class="py-4.5 px-6 text-center">
            <span class="px-2.5 py-1 rounded-lg bg-slate-100/90 group-hover:bg-amber-100/80 text-slate-500 group-hover:text-amber-900 font-mono font-black text-[11px] border border-slate-200/60 shadow-2xs transition">
              #${String(item.id).padStart(2, '0')}
            </span>
          </td>
          ${renderMasterTableColumns(sub, item)}
          <td class="py-4.5 px-6 text-center">
            <div class="flex items-center justify-center space-x-2">
              ${sub === 'keuskupan' ? `
                <button onclick='openCreateMasterModal("paroki", { keuskupan_id: ${item.id} })'
                  class="px-2.5 py-1.5 rounded-xl bg-blue-50 hover:bg-blue-100 border border-blue-200 text-blue-900 font-bold text-xs flex items-center space-x-1 transition shadow-sm transform hover:-translate-y-0.5" title="Tambah Paroki Baru di Keuskupan Ini">
                  <i data-lucide="plus" class="w-3.5 h-3.5 text-blue-600"></i>
                  <span>Paroki</span>
                </button>
              ` : ''}
              ${sub === 'paroki' ? `
                <button onclick='openCreateMasterModal("wilayah", { keuskupan_id: ${item.keuskupan_id || 'null'}, paroki_id: ${item.id} })'
                  class="px-2.5 py-1.5 rounded-xl bg-emerald-50 hover:bg-emerald-100 border border-emerald-200 text-emerald-900 font-bold text-xs flex items-center space-x-1 transition shadow-sm transform hover:-translate-y-0.5" title="Tambah Wilayah Baru di Paroki Ini">
                  <i data-lucide="plus" class="w-3.5 h-3.5 text-emerald-600"></i>
                  <span>Wilayah</span>
                </button>
              ` : ''}
              ${sub === 'wilayah' ? `
                <button onclick='openCreateMasterModal("lingkungan", { paroki_id: ${item.paroki_id || 'null'}, wilayah_id: ${item.id} })'
                  class="px-2.5 py-1.5 rounded-xl bg-indigo-50 hover:bg-indigo-100 border border-indigo-200 text-indigo-900 font-bold text-xs flex items-center space-x-1 transition shadow-sm transform hover:-translate-y-0.5" title="Tambah Lingkungan Baru di Wilayah Ini">
                  <i data-lucide="plus" class="w-3.5 h-3.5 text-indigo-600"></i>
                  <span>Lingkungan</span>
                </button>
              ` : ''}

              <button onclick='openEditMasterModal("${sub}", ${escapedItem})'
                class="px-3 py-1.5 rounded-xl bg-amber-50 hover:bg-amber-100 border border-amber-200 text-amber-900 font-bold text-xs flex items-center space-x-1.5 transition shadow-sm transform hover:-translate-y-0.5" title="Edit Data">
                <i data-lucide="edit" class="w-3.5 h-3.5 text-amber-600"></i>
                <span>Edit</span>
              </button>
              <button onclick='confirmDeleteMaster("${sub}", ${item.id}, "${(item.name || '').replace(/"/g, '')}")'
                class="px-3 py-1.5 rounded-xl bg-rose-50 hover:bg-rose-100 border border-rose-200 text-rose-900 font-bold text-xs flex items-center space-x-1.5 transition shadow-sm transform hover:-translate-y-0.5" title="Hapus Data">
                <i data-lucide="trash-2" class="w-3.5 h-3.5 text-rose-600"></i>
                <span>Hapus</span>
              </button>
            </div>
          </td>
        </tr>
      `;
    }
