// ── Orders & Service Monitoring Tab ──
    function isOrderDatePassed(dateStr) {
      if (!dateStr) return false;
      try {
        let cleanStr = String(dateStr);
        if (cleanStr.includes('T')) cleanStr = cleanStr.split('T')[0];
        const parts = cleanStr.split('-').map(Number);
        if (parts.length < 3 || isNaN(parts[0]) || isNaN(parts[1]) || isNaN(parts[2])) return false;
        const targetDate = new Date(parts[0], parts[1] - 1, parts[2]);
        const now = new Date();
        const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
        return targetDate < today;
      } catch (_) {
        return false;
      }
    }

    function getEffectiveOrderStatus(order) {
      if (!order) return 'PENDING';
      if (typeof order === 'string') return order.toUpperCase();
      const st = (order.status || '').toUpperCase();
      if (st === 'DONE' || st === 'CLOSE' || st === 'FAIL') return st;

      const romoAccepted = Boolean(order.acceptedRomoId || order.accepted_romo_id);
      const datePassed = isOrderDatePassed(order.scheduled_date || order.scheduledDate || (order.items && order.items[0]?.scheduled_date));
      if (datePassed) {
        return romoAccepted ? 'CLOSE' : 'FAIL';
      }
      return st || 'PENDING';
    }

    function getOrderStatusBadge(statusOrOrder) {
      const s = (statusOrOrder && typeof statusOrOrder === 'object') ? getEffectiveOrderStatus(statusOrOrder) : (statusOrOrder || '').toUpperCase();
      const map = {
        PENDING: { label: 'Menunggu Konfirmasi', icon: 'clock', cls: 'bg-amber-50 text-amber-900 border-amber-200', iconCls: 'text-amber-600' },
        CONFIRMED: { label: 'Telah Dikonfirmasi', icon: 'check-circle-2', cls: 'bg-emerald-50 text-emerald-900 border-emerald-200', iconCls: 'text-emerald-600' },
        ACCEPTED: { label: 'Telah Dikonfirmasi', icon: 'check-circle-2', cls: 'bg-emerald-50 text-emerald-900 border-emerald-200', iconCls: 'text-emerald-600' },
        IN_PROGRESS: { label: 'Sedang Berlangsung', icon: 'activity', cls: 'bg-blue-50 text-blue-900 border-blue-200', iconCls: 'text-blue-600' },
        PROCESS: { label: 'Sedang Berlangsung', icon: 'activity', cls: 'bg-blue-50 text-blue-900 border-blue-200', iconCls: 'text-blue-600' },
        ASSIGNED: { label: 'Sedang Berlangsung', icon: 'activity', cls: 'bg-blue-50 text-blue-900 border-blue-200', iconCls: 'text-blue-600' },
        ROMO_ASSIGNED: { label: 'Sedang Berlangsung', icon: 'activity', cls: 'bg-blue-50 text-blue-900 border-blue-200', iconCls: 'text-blue-600' },
        DONE: { label: 'Telah Selesai', icon: 'check-check', cls: 'bg-emerald-50 text-emerald-900 border-emerald-200', iconCls: 'text-emerald-600' },
        COMPLETED: { label: 'Telah Selesai', icon: 'check-check', cls: 'bg-emerald-50 text-emerald-900 border-emerald-200', iconCls: 'text-emerald-600' },
        CLOSE: { label: 'Closed (Ditutup Sistem)', icon: 'archive', cls: 'bg-teal-50 text-teal-900 border-teal-200', iconCls: 'text-teal-600' },
        CLOSED: { label: 'Closed (Ditutup Sistem)', icon: 'archive', cls: 'bg-teal-50 text-teal-900 border-teal-200', iconCls: 'text-teal-600' },
        FAIL: { label: 'Gagal / Kadaluarsa', icon: 'x-circle', cls: 'bg-rose-50 text-rose-900 border-rose-200', iconCls: 'text-rose-600' },
        CANCELLED: { label: 'Gagal / Kadaluarsa', icon: 'x-circle', cls: 'bg-rose-50 text-rose-900 border-rose-200', iconCls: 'text-rose-600' },
        DECLINED: { label: 'Ditolak', icon: 'x-circle', cls: 'bg-rose-50 text-rose-900 border-rose-200', iconCls: 'text-rose-600' },
        REJECTED: { label: 'Ditolak', icon: 'x-circle', cls: 'bg-rose-50 text-rose-900 border-rose-200', iconCls: 'text-rose-600' }
      };
      const cfg = map[s] || { label: s || '-', icon: 'info', cls: 'bg-slate-100 text-slate-700 border-slate-200', iconCls: 'text-slate-500' };
      return `<span class="inline-flex items-center space-x-1.5 px-2.5 py-1 rounded-full text-[11px] font-bold border shadow-2xs ${cfg.cls}"><i data-lucide="${cfg.icon}" class="w-3.5 h-3.5 ${cfg.iconCls}"></i><span>${cfg.label}</span></span>`;
    }

    function renderOrdersTab() {
      const q = state.orderSearch.toLowerCase();
      const filtered = state.orders.filter(o => {
        const oStatus = getEffectiveOrderStatus(o);
        const oCat = (o.category_name || o.categoryName || '').toLowerCase();
        const oNum = (o.order_number || o.orderNumber || '').toLowerCase();
        const oPem = (o.pemohon_name || o.pemohonName || '').toLowerCase();
        const oPar = (o.paroki_name || o.parokiName || o.location_name || o.locationName || '').toLowerCase();

        if (state.orderStatusFilter !== 'ALL' && oStatus !== state.orderStatusFilter) return false;
        if (state.orderCategoryFilter !== 'ALL' && !oCat.includes(state.orderCategoryFilter.toLowerCase())) return false;
        if (q) {
          if (!oNum.includes(q) && !oPem.includes(q) && !oPar.includes(q)) return false;
        }
        return true;
      });

      return `
        <div class="bg-white rounded-2xl border border-slate-200 shadow-sm">
          <div class="p-4 sm:p-5 border-b border-slate-200 flex flex-col sm:flex-row sm:items-center justify-between gap-3 sm:gap-4">
            <div class="flex items-center space-x-3 w-full sm:flex-1 min-w-0">
              <div class="relative w-full">
                <i data-lucide="search" class="w-4 h-4 absolute left-3.5 top-3.5 text-slate-400"></i>
                <input type="text" id="orderSearchInput" placeholder="Cari nomor order, pemohon, paroki..." value="${state.orderSearch}"
                  oninput="state.orderSearch = this.value; renderApp();"
                  class="w-full pl-10 pr-4 py-2.5 bg-slate-50 border border-slate-200 rounded-xl text-xs font-semibold focus:outline-none focus:ring-2 focus:ring-blue-950" />
              </div>
            </div>
            <div class="flex items-center space-x-2 w-full sm:w-auto">
              <select onchange="state.orderStatusFilter = this.value; renderApp();"
                class="w-full sm:w-auto px-3 py-2.5 bg-slate-50 border border-slate-200 rounded-xl text-xs font-bold text-slate-700 focus:outline-none focus:ring-2 focus:ring-blue-950">
                <option value="ALL" ${state.orderStatusFilter === 'ALL' ? 'selected' : ''}>Semua Status</option>
                <option value="PENDING" ${state.orderStatusFilter === 'PENDING' ? 'selected' : ''}>Menunggu Konfirmasi</option>
                <option value="CONFIRMED" ${state.orderStatusFilter === 'CONFIRMED' ? 'selected' : ''}>Telah Dikonfirmasi</option>
                <option value="IN_PROGRESS" ${state.orderStatusFilter === 'IN_PROGRESS' ? 'selected' : ''}>Sedang Berlangsung</option>
                <option value="DONE" ${state.orderStatusFilter === 'DONE' ? 'selected' : ''}>Telah Selesai</option>
                <option value="CLOSE" ${state.orderStatusFilter === 'CLOSE' ? 'selected' : ''}>Closed (Ditutup Sistem)</option>
                <option value="FAIL" ${state.orderStatusFilter === 'FAIL' ? 'selected' : ''}>Gagal / Ditolak</option>
              </select>
            </div>
          </div>

          <div class="overflow-x-auto">
            <table class="w-full min-w-[680px] text-left text-xs">
              <thead class="bg-slate-50 text-slate-500 font-bold border-b border-slate-200">
                <tr>
                  <th class="px-6 py-3.5">NO. ORDER</th>
                  <th class="px-6 py-3.5">KATEGORI</th>
                  <th class="px-6 py-3.5">PEMOHON</th>
                  <th class="px-6 py-3.5">PAROKI</th>
                  <th class="px-6 py-3.5">STATUS</th>
                  <th class="px-6 py-3.5 text-right">AKSI</th>
                </tr>
              </thead>
              <tbody class="divide-y divide-slate-200 font-medium text-slate-700">
                ${filtered.length === 0 ? `
                  <tr>
                    <td colspan="6" class="px-6 py-8 text-center text-slate-400 font-semibold">
                      Tidak ada permohonan yang sesuai dengan pencarian atau filter status.
                    </td>
                  </tr>
                ` : filtered.map(o => `
                  <tr class="hover:bg-slate-50/80 transition">
                    <td class="px-6 py-4 font-bold text-blue-950">${o.order_number || o.orderNumber}</td>
                    <td class="px-6 py-4 font-bold text-slate-900">${o.category_name || o.categoryName}</td>
                    <td class="px-6 py-4">${o.pemohon_name || o.pemohonName}</td>
                    <td class="px-6 py-4">${o.paroki_name || o.location_name || '-'}</td>
                    <td class="px-6 py-4 whitespace-nowrap">${getOrderStatusBadge(o)}</td>
                    <td class="px-6 py-4 text-right">
                      <button onclick="viewOrderDetail('${o.id}')" class="inline-flex items-center space-x-1 px-3 py-1.5 rounded-xl bg-blue-50 hover:bg-blue-100 text-blue-900 font-bold border border-blue-200 text-xs transition shadow-sm transform hover:-translate-y-0.5">
                        <i data-lucide="eye" class="w-3.5 h-3.5 text-blue-600"></i>
                        <span>Detail</span>
                      </button>
                    </td>
                  </tr>
                `).join('')}
              </tbody>
            </table>
          </div>
        </div>
      `;
    }

    // ── Tab: Umat Katolik ──

    function formatOrderDate(dateStr) {
      if (!dateStr) return '-';
      try {
        const parts = String(dateStr).split('T')[0].split('-');
        if (parts.length < 3) return dateStr;
        const months = ['Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'];
        return `${parseInt(parts[2], 10)} ${months[parseInt(parts[1], 10) - 1] || parts[1]} ${parts[0]}`;
      } catch (_) {
        return dateStr;
      }
    }

    function renderOrderNotes(notes) {
      if (!notes) return '<p class="text-slate-400 italic text-xs">Tidak ada catatan tambahan</p>';
      if (notes.includes('|')) {
        const parts = notes.split('|').map(p => p.trim()).filter(Boolean);
        return `
          <div class="grid grid-cols-1 sm:grid-cols-2 gap-2">
            ${parts.map(p => {
              const colonIdx = p.indexOf(':');
              if (colonIdx > 0) {
                const key = p.substring(0, colonIdx).trim();
                const val = p.substring(colonIdx + 1).trim();
                return `
                  <div class="bg-slate-50/70 p-2.5 rounded-lg border border-slate-100">
                    <span class="text-[10px] uppercase font-bold text-slate-400 block">${key}</span>
                    <span class="text-xs font-bold text-slate-800">${val || '-'}</span>
                  </div>
                `;
              }
              return `<div class="bg-slate-50/70 p-2.5 rounded-lg border border-slate-100 text-xs font-semibold text-slate-700">${p}</div>`;
            }).join('')}
          </div>
        `;
      }
      return `<div class="bg-slate-50/70 p-3 rounded-lg border border-slate-100 text-xs text-slate-700 font-medium whitespace-pre-wrap">${notes}</div>`;
    }

    function renderRomoAssignmentCard(o) {
      const s = getEffectiveOrderStatus(o);
      const isFailed = s === 'FAIL' || s === 'CANCELLED' || s === 'DECLINED' || s === 'REJECTED';
      const isDone = s === 'DONE' || s === 'COMPLETED';
      const isClose = s === 'CLOSE' || s === 'CLOSED';

      if (isFailed) {
        return `
          <div class="rounded-xl p-3.5 border bg-rose-50/70 border-rose-200/80 text-rose-950 space-y-1.5">
            <div class="flex items-center justify-between">
              <div class="flex items-center space-x-2">
                <i data-lucide="x-circle" class="w-4 h-4 text-rose-600 flex-shrink-0"></i>
                <span class="font-bold text-xs text-rose-900">Pelayanan Tidak Terlaksana (Kadaluarsa)</span>
              </div>
              <span class="text-[10px] font-bold px-2 py-0.5 rounded-full bg-rose-100 text-rose-800 border border-rose-200">Gagal / Kadaluarsa</span>
            </div>
            <p class="text-[11px] text-rose-700 pl-6 leading-relaxed">
              ${o.cancel_reason || o.cancellationReason || 'Batas jadwal pelayanan telah terlewati tanpa adanya Romo yang bertugas atau mengonfirmasi kehadiran.'}
            </p>
          </div>
        `;
      }

      if (o.acceptedRomoName) {
        return `
          <div class="rounded-xl p-3.5 border bg-emerald-50/60 border-emerald-200/80 text-emerald-900 space-y-1.5">
            <div class="flex items-center justify-between">
              <div class="flex items-center space-x-2">
                <i data-lucide="${(isDone || isClose) ? 'check-circle-2' : 'church'}" class="w-4 h-4 text-emerald-700 flex-shrink-0"></i>
                <span class="font-bold text-xs">Romo Pelayan: ${o.acceptedRomoName}</span>
              </div>
              <span class="text-[10px] font-bold px-2 py-0.5 rounded-full bg-emerald-100 text-emerald-800 border border-emerald-200">
                ${isDone ? 'Selesai Dilayani' : (isClose ? 'Ditutup Sistem' : 'Dikonfirmasi')}
              </span>
            </div>
            ${o.rescheduleStatus === 'ACCEPTED' ? `
              <p class="mt-1 text-[11px] text-amber-800 font-medium bg-amber-100/60 p-2 rounded-lg pl-6">
                <i data-lucide="refresh-cw" class="w-3.5 h-3.5 inline mr-1"></i>
                Jadwal diubah: ${o.rescheduleNewTime ? o.rescheduleNewTime.substring(0, 5) : ''} (${o.rescheduleReason || 'Penyesuaian waktu'})
              </p>
            ` : ''}
          </div>
        `;
      }

      return `
        <div class="rounded-xl p-3.5 border bg-amber-50/60 border-amber-200/80 text-amber-900 space-y-1">
          <div class="flex items-center justify-between">
            <div class="flex items-center space-x-2">
              <i data-lucide="clock" class="w-4 h-4 text-amber-700 flex-shrink-0"></i>
              <span class="font-bold text-xs">Belum Ada Romo Ditugaskan</span>
            </div>
            <span class="text-[10px] font-bold px-2 py-0.5 rounded-full bg-amber-100 text-amber-800 border border-amber-200">Menunggu</span>
          </div>
          <p class="text-[11px] text-amber-700 pl-6">Menunggu respon konfirmasi dari Romo di paroki/ordo setempat.</p>
        </div>
      `;
    }

    function renderOrderDetailModal() {
      const o = state.activeOrderDetail;
      if (!o) return '';
      const urgency = o.urgency_name || o.urgencyName || 'Biasa';
      const uLower = urgency.toLowerCase();
      const urgencyCls = uLower.includes('darurat') || uLower.includes('sangat')
        ? 'bg-rose-50 text-rose-700 border-rose-200'
        : (uLower.includes('penting') ? 'bg-amber-50 text-amber-700 border-amber-200' : 'bg-blue-50 text-blue-700 border-blue-200');

      return `
        <div class="fixed inset-0 z-50 bg-slate-900/40 backdrop-blur-xs flex items-center justify-center p-4 overflow-y-auto animate-fade-in">
          <div class="bg-white rounded-2xl max-w-lg w-full shadow-2xl border border-slate-100 p-6 space-y-5 my-8">
            
            <!-- Clean Header: Status, Badges, Title & Dismiss -->
            <div class="flex items-start justify-between gap-4 pb-4 border-b border-slate-100">
              <div class="space-y-1.5 min-w-0">
                <div class="flex flex-wrap items-center gap-2">
                  <span class="font-mono text-xs font-bold text-slate-600 bg-slate-100 px-2 py-0.5 rounded-md">${o.order_number || o.orderNumber}</span>
                  <span class="px-2 py-0.5 rounded-full text-[10px] font-bold border ${urgencyCls}">${urgency}</span>
                  ${getOrderStatusBadge(o)}
                </div>
                <h3 class="text-lg font-bold text-slate-900 tracking-tight">${o.category_name || o.categoryName}</h3>
              </div>
              <button onclick="state.activeOrderDetail = null; renderApp();" 
                class="p-1.5 rounded-xl text-slate-400 hover:text-slate-700 hover:bg-slate-100 transition flex-shrink-0" title="Tutup">
                <i data-lucide="x" class="w-5 h-5"></i>
              </button>
            </div>

            <!-- Modal Body Details -->
            <div class="space-y-4 max-h-[60vh] overflow-y-auto text-xs pr-1">
              <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
                <div class="bg-slate-50/70 rounded-xl p-3.5 border border-slate-100 space-y-1">
                  <div class="flex items-center space-x-1.5 text-slate-400 font-bold text-[10px] tracking-wider uppercase">
                    <i data-lucide="calendar" class="w-3.5 h-3.5 text-blue-600"></i>
                    <span>Jadwal Pelayanan</span>
                  </div>
                  <p class="font-bold text-slate-900 text-xs">${formatOrderDate(o.scheduled_date || o.scheduledDate)}</p>
                  <p class="text-slate-500 font-medium text-[11px]">${o.scheduled_time ? o.scheduled_time.substring(0, 5) + ' WIB' : 'Waktu menyusul'}</p>
                </div>
                <div class="bg-slate-50/70 rounded-xl p-3.5 border border-slate-100 space-y-1">
                  <div class="flex items-center space-x-1.5 text-slate-400 font-bold text-[10px] tracking-wider uppercase">
                    <i data-lucide="map-pin" class="w-3.5 h-3.5 text-rose-500"></i>
                    <span>Lokasi & Alamat</span>
                  </div>
                  <p class="font-bold text-slate-900 text-xs">${o.location_name || '-'}</p>
                  <p class="text-slate-500 font-medium text-[11px] line-clamp-2">${o.address_detail || '-'}</p>
                </div>
              </div>

              <div class="bg-slate-50/70 rounded-xl p-3.5 border border-slate-100 space-y-2.5">
                <div class="flex items-center justify-between">
                  <span class="font-bold text-slate-400 text-[10px] tracking-wider uppercase flex items-center space-x-1.5">
                    <i data-lucide="user" class="w-3.5 h-3.5 text-indigo-600"></i>
                    <span>Pemohon & Komunitas</span>
                  </span>
                  <span class="font-bold text-slate-900">${o.pemohon_name || o.pemohonName || '-'}</span>
                </div>
                <div class="grid grid-cols-3 gap-2 pt-2 border-t border-slate-200/60 text-slate-600">
                  <div>
                    <span class="text-[10px] text-slate-400 font-medium block">Keuskupan</span>
                    <span class="font-bold text-slate-800 text-[11px] truncate block">${o.keuskupan_name || '-'}</span>
                  </div>
                  <div>
                    <span class="text-[10px] text-slate-400 font-medium block">Paroki</span>
                    <span class="font-bold text-slate-800 text-[11px] truncate block">${o.paroki_name || '-'}</span>
                  </div>
                  <div>
                    <span class="text-[10px] text-slate-400 font-medium block">Lingkungan</span>
                    <span class="font-bold text-slate-800 text-[11px] truncate block">${o.lingkungan_name || '-'}</span>
                  </div>
                </div>
              </div>

              ${renderRomoAssignmentCard(o)}

              <div class="space-y-1.5">
                <span class="font-bold text-slate-400 text-[10px] tracking-wider uppercase flex items-center space-x-1.5">
                  <i data-lucide="file-text" class="w-3.5 h-3.5 text-blue-600"></i>
                  <span>Detail Penerima & Catatan Khusus</span>
                </span>
                ${renderOrderNotes(o.notes)}
              </div>
            </div>

            <!-- Modal Clean Footer -->
            <div class="pt-4 border-t border-slate-100 flex justify-end">
              <button onclick="state.activeOrderDetail = null; renderApp();" 
                class="px-5 py-2 rounded-xl bg-slate-100 hover:bg-slate-200 text-slate-700 font-bold text-xs transition">
                Tutup
              </button>
            </div>
          </div>
        </div>
      `;
    }

    function renderChatModal() {
      return `<div class="fixed inset-0 z-50 bg-black/60 flex items-center justify-center"><p class="text-white">Chat</p></div>`;
    }


    function viewOrderDetail(orderId) {
      state.activeOrderDetail = state.orders.find(o => String(o.id) === String(orderId));
      renderApp();
    }
