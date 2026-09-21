// ── Master Data Table Columns View ──
    function renderMasterTableColumns(sub, item) {
      if (sub === 'keuskupan') {
        return `
          <td class="py-4 px-6 font-bold text-slate-900 text-xs">${item.name}</td>
          <td class="py-4 px-6 font-semibold text-slate-800 text-xs">${item.total_paroki || 0} Paroki</td>
          <td class="py-4 px-6 text-slate-700 font-medium text-xs">${item.created_at ? new Date(item.created_at).toLocaleDateString('id-ID', { year: 'numeric', month: 'short', day: 'numeric' }) : 'Aktif'}</td>
        `;
      }
      if (sub === 'paroki') {
        return `
          <td class="py-4 px-6 font-bold text-slate-900 text-xs">${item.name}</td>
          <td class="py-4 px-6 text-slate-700 font-medium text-xs max-w-[180px] truncate">${item.keuskupan_name || '-'}</td>
          <td class="py-4 px-6 font-semibold text-slate-800 text-xs">${item.total_wilayah || 0} Wilayah</td>
        `;
      }
      if (sub === 'wilayah') {
        return `
          <td class="py-4 px-6 font-bold text-slate-900 text-xs">${item.name}</td>
          <td class="py-4 px-6 text-slate-700 font-medium text-xs max-w-[180px] truncate">${item.paroki_name || '-'}</td>
          <td class="py-4 px-6 text-slate-700 font-medium text-xs max-w-[180px] truncate">${item.keuskupan_name || '-'}</td>
          <td class="py-4 px-6 font-semibold text-slate-800 text-xs">${item.total_lingkungan || 0} Lingkungan</td>
        `;
      }
      if (sub === 'lingkungan') {
        return `
          <td class="py-4 px-6 font-bold text-slate-900 text-xs">${item.name}</td>
          <td class="py-4 px-6 text-slate-700 font-medium text-xs max-w-[180px] truncate">${item.wilayah_name || '-'}</td>
          <td class="py-4 px-6 text-slate-700 font-medium text-xs max-w-[180px] truncate">${item.paroki_name || '-'}</td>
          <td class="py-4 px-6 font-semibold text-slate-800 text-xs">${item.total_umat || 0} Umat</td>
        `;
      }
      if (sub === 'ordo') {
        return `
          <td class="py-4 px-6 font-bold text-slate-900 text-xs">${item.name}</td>
          <td class="py-4 px-6 font-mono font-bold text-slate-800 text-xs">${item.code || '-'}</td>
          <td class="py-4 px-6 font-semibold text-slate-800 text-xs">${item.total_romo || 0} Romo</td>
          <td class="py-4 px-6 text-slate-700 font-medium text-xs max-w-xs truncate" title="${item.address || ''}">${item.address || 'Alamat belum diatur'}</td>
        `;
      }
      if (sub === 'services') {
        return `
          <td class="py-4 px-6 font-bold text-slate-900 text-xs">${item.name}</td>
          <td class="py-4 px-6 text-slate-700 font-medium text-xs max-w-xs truncate" title="${item.description || ''}">${item.description || '-'}</td>
          <td class="py-4 px-6 text-center font-bold text-xs ${item.is_urgent_by_default ? 'text-rose-600' : 'text-slate-500'}">${item.is_urgent_by_default ? 'URGENT' : 'NORMAL'}</td>
          <td class="py-4 px-6 text-center font-bold text-xs ${item.is_active ? 'text-emerald-600' : 'text-slate-400'}">${item.is_active ? 'AKTIF' : 'NON-AKTIF'}</td>
          <td class="py-4 px-6 font-semibold text-slate-800 text-xs">${item.total_orders || 0} Order</td>
        `;
      }
      if (sub === 'roles') {
        return `
          <td class="py-4 px-6 font-mono font-bold text-slate-800 text-xs">${item.code || '-'}</td>
          <td class="py-4 px-6 font-bold text-slate-900 text-xs">${item.name || '-'}</td>
          <td class="py-4 px-6 font-semibold text-slate-800 text-xs">${item.total_users || 0} Pengguna</td>
          <td class="py-4 px-6 text-slate-700 font-medium text-xs">${['ADMIN', 'SUPERADMIN'].includes(item.code) ? 'Portal Administrator Web' : 'Aplikasi Mobile CATU'}</td>
        `;
      }
      if (sub === 'positions') {
        const catLabel = item.category === 'PENGURUS_LINGKUNGAN' ? 'Pengurus Lingkungan' : item.category === 'ROMO_PAROKI' ? 'Romo Paroki' : 'Romo Ordo';
        return `
          <td class="py-4 px-6 font-mono font-bold text-slate-800 text-xs">${item.code || '-'}</td>
          <td class="py-4 px-6 font-bold text-slate-900 text-xs">${item.name || '-'}</td>
          <td class="py-4 px-6 text-slate-700 font-medium text-xs">${catLabel}</td>
          <td class="py-4 px-6 text-slate-800 font-semibold text-xs">${item.is_lead ? 'Ketua / Kepala' : 'Anggota'}</td>
          <td class="py-4 px-6 font-semibold text-slate-800 text-xs">${item.total_pejabat || 0} Pejabat</td>
        `;
      }
      return '';
    }

    // ── Master Modal (Create / Edit) ──