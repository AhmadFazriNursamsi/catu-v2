// ── Orders & Service Monitoring Tab ──
    function renderOrdersTab() {
      const q = state.orderSearch.toLowerCase();
      const filtered = state.orders.filter(o => {
        const oStatus = (o.status || '').toUpperCase();
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
          <div class="p-5 border-b border-slate-200 flex flex-wrap items-center justify-between gap-4">
            <div class="flex items-center space-x-3 flex-1 min-w-[280px]">
              <div class="relative w-full">
                <i data-lucide="search" class="w-4 h-4 absolute left-3.5 top-3.5 text-slate-400"></i>
                <input type="text" id="orderSearchInput" placeholder="Cari nomor order, pemohon, paroki..." value="${state.orderSearch}"
                  oninput="state.orderSearch = this.value; renderApp();"
                  class="w-full pl-10 pr-4 py-2.5 bg-slate-50 border border-slate-200 rounded-xl text-xs font-semibold focus:outline-none focus:ring-2 focus:ring-blue-950" />
              </div>
            </div>
          </div>

          <div class="overflow-x-auto">
            <table class="w-full text-left text-xs">
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
                ${filtered.map(o => `
                  <tr class="hover:bg-slate-50/80 transition">
                    <td class="px-6 py-4 font-bold text-blue-950">${o.order_number || o.orderNumber}</td>
                    <td class="px-6 py-4 font-bold text-slate-900">${o.category_name || o.categoryName}</td>
                    <td class="px-6 py-4">${o.pemohon_name || o.pemohonName}</td>
                    <td class="px-6 py-4">${o.paroki_name || o.location_name || '-'}</td>
                    <td class="px-6 py-4"><span class="px-2.5 py-1 rounded-md font-bold text-[11px] ${getStatusBadgeClass(o.status)}">${o.status}</span></td>
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

    function renderOrderDetailModal() {
      const o = state.activeOrderDetail;
      return `
        <div class="fixed inset-0 z-50 bg-black/60 backdrop-blur-sm flex items-center justify-center p-4">
          <div class="bg-white rounded-3xl max-w-lg w-full p-6 shadow-2xl border border-slate-200 space-y-4 text-xs">
            <h3 class="font-extrabold text-sm">${o.order_number || o.orderNumber} - ${o.category_name || o.categoryName}</h3>
            <p>Pemohon: <strong>${o.pemohon_name || o.pemohonName}</strong></p>
            <p>Paroki: <strong>${o.paroki_name || '-'}</strong></p>
            <div class="flex justify-end pt-3">
              <button onclick="state.activeOrderDetail = null; renderApp();" class="px-4 py-2 rounded-xl bg-blue-950 text-white font-bold">Tutup</button>
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

