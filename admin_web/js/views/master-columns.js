// ── Master Data Table Columns View ──
    function renderMasterTableColumns(sub, item) {
      if (sub === 'keuskupan') {
        return `
          <td class="py-4.5 px-6">
            <div>
              <p class="font-extrabold text-slate-900 text-xs">${item.name}</p>
              <p class="text-[10px] text-blue-800 font-bold">Keuskupan Katolik</p>
            </div>
          </td>
          <td class="py-4.5 px-6">
            <span class="px-2.5 py-1 rounded-xl bg-slate-900 text-amber-300 font-mono font-black text-xs border border-slate-800 shadow-2xs">
              ${item.code || '-'}
            </span>
          </td>
          <td class="py-4.5 px-6 text-center">
            <span class="inline-flex items-center px-3.5 py-1.5 rounded-full bg-blue-50 text-blue-950 font-black text-xs border border-blue-200 shadow-2xs">
              <span>${item.total_paroki || 0} Paroki</span>
            </span>
          </td>
          <td class="py-4.5 px-6 text-slate-600 font-bold text-xs">
            <div class="inline-flex items-center px-3 py-1.5 rounded-xl bg-slate-50 border border-slate-200/80 text-slate-700 text-xs font-bold">
              <span>${item.created_at ? new Date(item.created_at).toLocaleDateString('id-ID', { year: 'numeric', month: 'short', day: 'numeric' }) : 'Aktif'}</span>
            </div>
          </td>
        `;
      } else if (sub === 'paroki') {
        return `
          <td class="py-4.5 px-6">
            <div>
              <p class="font-extrabold text-blue-950 text-xs">${item.name}</p>
              <p class="text-[10px] text-emerald-700 font-bold">Gereja Paroki</p>
            </div>
          </td>
          <td class="py-4.5 px-6">
            <div class="inline-flex items-center px-3 py-1.5 rounded-xl bg-blue-50 text-blue-950 font-extrabold border border-blue-200 text-xs shadow-2xs">
              <span>${item.keuskupan_name || '-'}</span>
            </div>
          </td>
          <td class="py-4.5 px-6 text-center">
            <span class="inline-flex items-center px-3.5 py-1.5 rounded-full bg-emerald-50 text-emerald-950 font-black text-xs border border-emerald-200 shadow-2xs">
              <span>${item.total_wilayah || 0} Wilayah</span>
            </span>
          </td>
          <td class="py-4.5 px-6 text-slate-600 font-medium text-xs max-w-xs truncate" title="${item.address || ''}">
            <div class="inline-flex items-center px-3 py-1.5 rounded-xl bg-slate-50 border border-slate-200/80 text-slate-700 text-xs font-semibold max-w-full">
              <span class="truncate">${item.address || 'Alamat belum diatur'}</span>
            </div>
          </td>
        `;
      } else if (sub === 'wilayah') {
        return `
          <td class="py-4.5 px-6">
            <div>
              <p class="font-extrabold text-indigo-950 text-xs">${item.name}</p>
              <p class="text-[10px] text-indigo-700 font-bold">Wilayah Gereja</p>
            </div>
          </td>
          <td class="py-4.5 px-6">
            <div class="inline-flex items-center px-3 py-1.5 rounded-xl bg-emerald-50 text-emerald-950 font-extrabold border border-emerald-200 text-xs shadow-2xs">
              <span>${item.paroki_name || '-'}</span>
            </div>
          </td>
          <td class="py-4.5 px-6">
            <div class="inline-flex items-center px-3 py-1.5 rounded-xl bg-blue-50 text-blue-950 font-extrabold border border-blue-200 text-xs shadow-2xs">
              <span>${item.keuskupan_name || '-'}</span>
            </div>
          </td>
          <td class="py-4.5 px-6 text-center">
            <span class="inline-flex items-center px-3.5 py-1.5 rounded-full bg-indigo-50 text-indigo-950 font-black text-xs border border-indigo-200 shadow-2xs">
              <span>${item.total_lingkungan || 0} Lingkungan</span>
            </span>
          </td>
        `;
      } else if (sub === 'lingkungan') {
        return `
          <td class="py-4.5 px-6">
            <div>
              <p class="font-extrabold text-blue-950 text-xs">${item.name}</p>
              <p class="text-[10px] text-cyan-700 font-bold">Komunitas Lingkungan</p>
            </div>
          </td>
          <td class="py-4.5 px-6">
            <div class="inline-flex items-center px-3 py-1.5 rounded-xl bg-indigo-50 text-indigo-950 font-extrabold border border-indigo-200 text-xs shadow-2xs">
              <span>${item.wilayah_name || '-'}</span>
            </div>
          </td>
          <td class="py-4.5 px-6">
            <div class="inline-flex items-center px-3 py-1.5 rounded-xl bg-emerald-50 text-emerald-950 font-extrabold border border-emerald-200 text-xs shadow-2xs">
              <span>${item.paroki_name || '-'}</span>
            </div>
          </td>
          <td class="py-4.5 px-6 text-center">
            <span class="inline-flex items-center px-3.5 py-1.5 rounded-full bg-cyan-50 text-cyan-950 font-black text-xs border border-cyan-200 shadow-2xs">
              <span>${item.total_umat || 0} Umat</span>
            </span>
          </td>
        `;
      } else if (sub === 'ordo') {
        return `
          <td class="py-4.5 px-6">
            <div>
              <p class="font-extrabold text-purple-950 text-xs">${item.name}</p>
              <p class="text-[10px] text-purple-700 font-bold">Ordo / Kongregasi Religius</p>
            </div>
          </td>
          <td class="py-4.5 px-6">
            <span class="px-2.5 py-1 rounded-xl bg-purple-100 text-purple-950 font-mono font-black text-xs border border-purple-300 shadow-2xs">
              ${item.code || '-'}
            </span>
          </td>
          <td class="py-4.5 px-6 text-center">
            <span class="inline-flex items-center px-3.5 py-1.5 rounded-full bg-purple-50 text-purple-950 font-black text-xs border border-purple-200 shadow-2xs">
              <span>${item.total_romo || 0} Romo</span>
            </span>
          </td>
          <td class="py-4.5 px-6 text-slate-600 font-medium text-xs max-w-xs truncate" title="${item.address || ''}">
            <div class="inline-flex items-center px-3 py-1.5 rounded-xl bg-slate-50 border border-slate-200/80 text-slate-700 text-xs font-semibold max-w-full">
              <span class="truncate">${item.address || 'Alamat belum diatur'}</span>
            </div>
          </td>
        `;
      } else if (sub === 'services') {
        return `
          <td class="py-4.5 px-6">
            <div>
              <p class="font-extrabold text-slate-900 text-xs">${item.name}</p>
              <p class="text-[10px] text-amber-700 font-bold">Layanan Sakramen</p>
            </div>
          </td>
          <td class="py-4.5 px-6 text-slate-600 font-medium text-xs max-w-xs truncate" title="${item.description || ''}">
            <div class="inline-flex items-center px-3 py-1.5 rounded-xl bg-slate-50 border border-slate-200/80 text-slate-700 text-xs font-semibold max-w-full">
              <span class="truncate">${item.description || 'Tidak ada deskripsi'}</span>
            </div>
          </td>
          <td class="py-4.5 px-6 text-center">
            <span class="inline-flex items-center px-3 py-1.5 rounded-full text-[11px] font-black ${
              item.is_urgent_by_default 
                ? 'bg-rose-100 text-rose-900 border border-rose-300 shadow-2xs animate-pulse' 
                : 'bg-slate-100 text-slate-600 border border-slate-200'
            }">
              <span>${item.is_urgent_by_default ? 'URGENT' : 'NORMAL'}</span>
            </span>
          </td>
          <td class="py-4.5 px-6 text-center">
            <span class="inline-flex items-center px-3 py-1.5 rounded-full text-[11px] font-black ${
              item.is_active 
                ? 'bg-emerald-100 text-emerald-950 border border-emerald-300 shadow-2xs' 
                : 'bg-slate-100 text-slate-500 border border-slate-200'
            }">
              <span>${item.is_active ? 'AKTIF' : 'NON-AKTIF'}</span>
            </span>
          </td>
          <td class="py-4.5 px-6 text-center font-black text-slate-800 text-xs">
            <span class="inline-flex items-center px-3.5 py-1.5 rounded-full bg-slate-100 text-slate-800 border border-slate-200 font-black text-xs">
              <span>${item.total_orders || 0} Order</span>
            </span>
          </td>
        `;
      } else if (sub === 'roles') {
        return `
          <td class="py-4.5 px-6">
            <span class="px-2.5 py-1 rounded-xl bg-slate-900 text-amber-300 font-mono font-black text-xs border border-slate-800 shadow-2xs">
              ${item.code || '-'}
            </span>
          </td>
          <td class="py-4.5 px-6 font-black text-slate-900 text-xs">
            <div>
              <p class="font-extrabold text-slate-900 text-xs">${item.name || '-'}</p>
              <p class="text-[10px] text-slate-400 font-semibold">Role Akun</p>
            </div>
          </td>
          <td class="py-4.5 px-6 text-center">
            <span class="inline-flex items-center px-3.5 py-1.5 rounded-full text-xs font-bold bg-slate-100 text-slate-700 border border-slate-200">
              <span>${item.total_users || 0} Pengguna</span>
            </span>
          </td>
          <td class="py-4.5 px-6">
            <span class="inline-flex items-center px-3 py-1.5 rounded-xl text-xs font-bold ${item.code === 'ADMIN' ? 'text-amber-950 bg-amber-50 border border-amber-300' : 'text-slate-700 bg-slate-100 border border-slate-200'}">
              <span>${item.code === 'ADMIN' ? 'Portal Administrator Web' : 'Aplikasi Mobile CATU'}</span>
            </span>
          </td>
        `;
      } else if (sub === 'positions') {
        const catBadge = item.category === 'PENGURUS_LINGKUNGAN'
          ? '<span class="inline-flex items-center px-3 py-1.5 rounded-xl bg-slate-100 text-slate-800 border border-slate-200 font-bold text-xs"><span>Pengurus Lingkungan</span></span>'
          : item.category === 'ROMO_PAROKI'
          ? '<span class="inline-flex items-center px-3 py-1.5 rounded-xl bg-slate-100 text-slate-800 border border-slate-200 font-bold text-xs"><span>Romo Paroki</span></span>'
          : '<span class="inline-flex items-center px-3 py-1.5 rounded-xl bg-slate-100 text-slate-800 border border-slate-200 font-bold text-xs"><span>Romo Ordo</span></span>';
        return `
          <td class="py-4.5 px-6">
            <span class="px-2.5 py-1 rounded-xl bg-slate-900 text-amber-300 font-mono font-bold text-xs border border-slate-800 shadow-2xs">
              ${item.code || '-'}
            </span>
          </td>
          <td class="py-4.5 px-6 font-bold text-slate-900 text-xs">
            <div>
              <p class="font-bold text-slate-900 text-xs">${item.name || '-'}</p>
              <p class="text-[10px] text-slate-400 font-semibold">${item.is_lead ? 'Pimpinan / Ketua Utama' : 'Struktur Anggota'}</p>
            </div>
          </td>
          <td class="py-4.5 px-6">
            ${catBadge}
          </td>
          <td class="py-4.5 px-6 text-center">
            <span class="inline-flex items-center px-3.5 py-1.5 rounded-full text-xs font-bold ${item.is_lead ? 'bg-amber-100 text-amber-950 border border-amber-300' : 'bg-slate-100 text-slate-600 border border-slate-200'}">
              <span>${item.is_lead ? 'KETUA / KEPALA' : 'ANGGOTA'}</span>
            </span>
          </td>
          <td class="py-4.5 px-6 text-center">
            <span class="inline-flex items-center px-3.5 py-1.5 rounded-full text-xs font-bold bg-slate-100 text-slate-700 border border-slate-200">
              <span>${item.total_pejabat || 0} Pejabat</span>
            </span>
          </td>
        `;
      }
      return '';
    }

    // ── Master Modal (Create / Edit) ──