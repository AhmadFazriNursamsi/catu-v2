// ── Overview Dashboard & Monitoring Tab ──
    function renderOverviewTab() {
      const orders = state.analytics?.orders || {};
      const users = state.analytics?.users || {};
      const recentOrders = (state.orders || []).slice(0, 5);
      const pendingOrders = (state.orders || []).filter(o => getEffectiveOrderStatus(o) === 'PENDING').length;
      const totalUmat = (state.users || []).filter(u => (u.role_code || u.roleCode) === 'UMAT').length || users.total_umat || 0;
      const pendingUsers = (state.users || []).filter(u => (u.account_status || u.accountStatus) === 'PENDING_APPROVAL').length;
      const totalRomo = (state.users || []).filter(u => {
        const r = (u.role_code || u.roleCode || '').toUpperCase();
        return r === 'ROMO_PAROKI' || r === 'ROMO_ORDO';
      }).length || ((parseInt(users.total_romo_paroki || 0, 10) + parseInt(users.total_romo_ordo || 0, 10)) || 0);
      const totalParoki = (state.paroki || []).length;
      const totalKeuskupan = (state.keuskupan || []).length;

      return `
        <div class="space-y-6">
          <!-- Page Header -->
          <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-2 pb-1">
            <div>
              <h2 class="text-xl font-extrabold text-slate-900 tracking-tight">Ringkasan Pelayanan Pastoral</h2>
              <p class="text-xs text-slate-500 mt-0.5">Pemantauan permohonan sakramen, koordinasi Romo pelayan, dan administrasi keumatan.</p>
            </div>
            <div class="flex items-center space-x-2">
              <button onclick="setTab('orders')" class="inline-flex items-center space-x-1.5 px-3.5 py-2 rounded-xl bg-blue-900 hover:bg-blue-950 text-white font-bold text-xs shadow-xs transition">
                <i data-lucide="clipboard-list" class="w-3.5 h-3.5"></i>
                <span>Kelola Permohonan</span>
              </button>
            </div>
          </div>

          <!-- 4 Pastoral KPI Cards -->
          <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-3.5 sm:gap-5">
            <div class="bg-white rounded-2xl p-5 border border-slate-200 shadow-xs cursor-pointer hover:border-blue-900/40 transition" onclick="setTab('orders')">
              <div class="flex items-center justify-between mb-3">
                <div class="w-10 h-10 rounded-xl bg-blue-50 text-blue-900 flex items-center justify-center font-bold">
                  <i data-lucide="clipboard-list" class="w-5 h-5"></i>
                </div>
                <span class="text-[11px] font-bold px-2.5 py-0.5 rounded-full ${pendingOrders > 0 ? 'bg-amber-50 text-amber-800 border border-amber-200' : 'bg-slate-100 text-slate-600'}">
                  ${pendingOrders} Menunggu
                </span>
              </div>
              <h3 class="text-2xl font-extrabold text-slate-900">${state.orders.length || orders.total || 0}</h3>
              <p class="text-xs font-semibold text-slate-600 mt-0.5">Permohonan Pelayanan</p>
            </div>

            <div class="bg-white rounded-2xl p-5 border border-slate-200 shadow-xs cursor-pointer hover:border-blue-900/40 transition" onclick="setTab('umat')">
              <div class="flex items-center justify-between mb-3">
                <div class="w-10 h-10 rounded-xl bg-slate-100 text-slate-700 flex items-center justify-center font-bold">
                  <i data-lucide="users" class="w-5 h-5"></i>
                </div>
                ${pendingUsers > 0 ? `
                  <span class="text-[11px] font-bold px-2.5 py-0.5 rounded-full bg-amber-50 text-amber-800 border border-amber-200 cursor-pointer" onclick="event.stopPropagation(); setTab('approvals');">
                    ${pendingUsers} Verifikasi
                  </span>
                ` : `
                  <span class="text-[11px] font-bold px-2.5 py-0.5 rounded-full bg-slate-100 text-slate-600">
                    Aktif
                  </span>
                `}
              </div>
              <h3 class="text-2xl font-extrabold text-slate-900">${totalUmat}</h3>
              <p class="text-xs font-semibold text-slate-600 mt-0.5">Umat Katolik Terdaftar</p>
            </div>

            <div class="bg-white rounded-2xl p-5 border border-slate-200 shadow-xs cursor-pointer hover:border-blue-900/40 transition" onclick="setTab('romo_paroki')">
              <div class="flex items-center justify-between mb-3">
                <div class="w-10 h-10 rounded-xl bg-amber-50 text-amber-800 flex items-center justify-center font-bold">
                  <i data-lucide="church" class="w-5 h-5"></i>
                </div>
                <span class="text-[11px] font-bold px-2.5 py-0.5 rounded-full bg-slate-100 text-slate-600">
                  Paroki & Ordo
                </span>
              </div>
              <h3 class="text-2xl font-extrabold text-slate-900">${totalRomo}</h3>
              <p class="text-xs font-semibold text-slate-600 mt-0.5">Romo Pelayan Siap Bertugas</p>
            </div>

            <div class="bg-white rounded-2xl p-5 border border-slate-200 shadow-xs cursor-pointer hover:border-blue-900/40 transition" onclick="setTab('master')">
              <div class="flex items-center justify-between mb-3">
                <div class="w-10 h-10 rounded-xl bg-slate-100 text-slate-700 flex items-center justify-center font-bold">
                  <i data-lucide="map-pin" class="w-5 h-5"></i>
                </div>
                <span class="text-[11px] font-bold px-2.5 py-0.5 rounded-full bg-blue-50 text-blue-800 border border-blue-200">
                  ${totalKeuskupan} Keuskupan
                </span>
              </div>
              <h3 class="text-2xl font-extrabold text-slate-900">${totalParoki}</h3>
              <p class="text-xs font-semibold text-slate-600 mt-0.5">Paroki Terdaftar di Sistem</p>
            </div>
          </div>

          <!-- Section: Permohonan Sakramen Terbaru -->
          <div class="bg-white rounded-2xl border border-slate-200 shadow-xs overflow-hidden">
            <div class="p-4 sm:p-5 border-b border-slate-200 flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <div>
                <h3 class="text-sm font-extrabold text-slate-900">Permohonan Sakramen Terbaru</h3>
                <p class="text-xs text-slate-500 mt-0.5">Daftar permohonan terkini yang diajukan oleh umat paroki.</p>
              </div>
              <button onclick="setTab('orders')" class="text-xs font-bold text-blue-900 hover:text-blue-950 flex items-center space-x-1">
                <span>Lihat Semua Permohonan</span>
                <i data-lucide="arrow-right" class="w-3.5 h-3.5"></i>
              </button>
            </div>

            <div class="overflow-x-auto">
              <table class="w-full min-w-[640px] text-left text-xs">
                <thead class="bg-slate-50 text-slate-500 font-bold border-b border-slate-200">
                  <tr>
                    <th class="px-6 py-3.5">NO. ORDER</th>
                    <th class="px-6 py-3.5">KATEGORI PELAYANAN</th>
                    <th class="px-6 py-3.5">PEMOHON</th>
                    <th class="px-6 py-3.5">PAROKI</th>
                    <th class="px-6 py-3.5">STATUS</th>
                    <th class="px-6 py-3.5 text-right">AKSI</th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-slate-200 font-medium text-slate-700">
                  ${recentOrders.length === 0 ? `
                    <tr>
                      <td colspan="6" class="px-6 py-8 text-center text-slate-400 font-semibold">
                        Belum ada data permohonan sakramen.
                      </td>
                    </tr>
                  ` : recentOrders.map(o => `
                    <tr class="hover:bg-slate-50/70 transition">
                      <td class="px-6 py-3.5 font-bold text-blue-950 font-mono">${o.order_number || o.orderNumber}</td>
                      <td class="px-6 py-3.5 font-bold text-slate-900">${o.category_name || o.categoryName}</td>
                      <td class="px-6 py-3.5">${o.pemohon_name || o.pemohonName}</td>
                      <td class="px-6 py-3.5">${o.paroki_name || o.location_name || '-'}</td>
                      <td class="px-6 py-3.5 whitespace-nowrap">${getOrderStatusBadge(o)}</td>
                      <td class="px-6 py-3.5 text-right">
                        <button onclick="viewOrderDetail('${o.id}')" class="inline-flex items-center space-x-1 px-3 py-1 rounded-lg bg-slate-100 hover:bg-slate-200 text-slate-800 font-bold text-xs transition">
                          <i data-lucide="eye" class="w-3 h-3 text-slate-600"></i>
                          <span>Detail</span>
                        </button>
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

    function renderChatTab() {
      return `
        <div class="bg-white rounded-2xl p-6 border border-slate-200 shadow-xs space-y-3">
          <div class="flex items-center space-x-3">
            <div class="w-10 h-10 rounded-xl bg-blue-50 text-blue-900 flex items-center justify-center font-bold">
              <i data-lucide="messages-square" class="w-5 h-5"></i>
            </div>
            <div>
              <h3 class="text-sm font-extrabold text-slate-900">Monitoring Komunikasi Chat Pelayanan</h3>
              <p class="text-xs text-slate-500">Pemantauan pesan antara Umat dan Romo pelayan saat permohonan berlangsung.</p>
            </div>
          </div>
          <div class="p-8 text-center text-slate-400 text-xs font-semibold bg-slate-50 rounded-xl border border-dashed border-slate-200">
            Pilih salah satu permohonan aktif dari menu Permohonan untuk melihat riwayat pesan chat terkait.
          </div>
        </div>
      `;
    }

    // ══════════════════════════════════════════════════════════════════════════
    // 4. 🎯 AGENTATION TOOLBAR & FLOATING INSPECTOR
    // ══════════════════════════════════════════════════════════════════════════
