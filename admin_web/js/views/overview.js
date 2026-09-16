// ── Overview Dashboard, Chat & QA Tabs ──
    function renderOverviewTab() {
      const orders = state.analytics?.orders || {};
      const users = state.analytics?.users || {};
      const categories = state.analytics?.categories || [];
      const recentOrders = state.analytics?.recentOrders || [];

      return `
        <div class="space-y-8">
          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
            <div class="bg-white rounded-2xl p-6 border border-slate-200 shadow-sm cursor-pointer hover:border-blue-500 transition" onclick="setTab('orders')">
              <div class="flex items-center justify-between mb-4">
                <div class="p-3 rounded-xl bg-blue-50 text-blue-950"><i data-lucide="clipboard-list" class="w-6 h-6"></i></div>
                <span class="text-xs font-bold px-2.5 py-1 rounded-full bg-amber-50 text-amber-700 border border-amber-200">${orders.pending || 0} Menunggu</span>
              </div>
              <h3 class="text-2xl font-extrabold text-slate-900">${orders.total || state.orders.length}</h3>
              <p class="text-xs font-bold text-slate-600">Total Permintaan Pelayanan</p>
            </div>

            <div class="bg-white rounded-2xl p-6 border border-slate-200 shadow-sm cursor-pointer hover:border-blue-500 transition" onclick="setTab('umat')">
              <div class="flex items-center justify-between mb-4">
                <div class="p-3 rounded-xl bg-emerald-50 text-emerald-700"><i data-lucide="users" class="w-6 h-6"></i></div>
                <span class="text-xs font-bold px-2.5 py-1 rounded-full bg-blue-50 text-blue-700 border border-blue-200">${users.total_umat || 0} Umat</span>
              </div>
              <h3 class="text-2xl font-extrabold text-slate-900">${users.total || state.users.length}</h3>
              <p class="text-xs font-bold text-slate-600">Total Pengguna Terdaftar</p>
            </div>

            <div class="bg-white rounded-2xl p-6 border border-slate-200 shadow-sm cursor-pointer hover:border-blue-500 transition" onclick="setTab('romo_paroki')">
              <div class="flex items-center justify-between mb-4">
                <div class="p-3 rounded-xl bg-purple-50 text-purple-700"><i data-lucide="church" class="w-6 h-6"></i></div>
                <span class="text-xs font-bold px-2.5 py-1 rounded-full bg-purple-50 text-purple-700 border border-purple-200">Romo Pelayan</span>
              </div>
              <h3 class="text-2xl font-extrabold text-slate-900">${(parseInt(users.total_romo_paroki || 0) + parseInt(users.total_romo_ordo || 0))}</h3>
              <p class="text-xs font-bold text-slate-600">Total Romo Paroki & Ordo</p>
            </div>

            <div class="bg-white rounded-2xl p-6 border border-slate-200 shadow-sm">
              <div class="flex items-center justify-between mb-4">
                <div class="p-3 rounded-xl bg-cyan-50 text-cyan-700"><i data-lucide="server" class="w-6 h-6"></i></div>
                <span class="text-xs font-bold px-2.5 py-1 rounded-full bg-emerald-50 text-emerald-700 border border-emerald-200">100% OK</span>
              </div>
              <h3 class="text-2xl font-extrabold text-slate-900">Online</h3>
              <p class="text-xs font-bold text-slate-600">Backend & PostgreSQL</p>
            </div>
          </div>
        </div>
      `;
    }

    // ── Tab: Orders ──

    function renderChatTab() {
      return `<div class="bg-white rounded-2xl p-6 border border-slate-200 shadow-sm"><p class="text-xs font-bold">Monitoring Chat Aktif</p></div>`;
    }

    function renderQATab() {
      return `
        <div class="bg-white rounded-2xl p-6 border border-slate-200 shadow-sm space-y-4">
          <div class="flex items-center justify-between">
            <h3 class="text-sm font-bold text-slate-900">Live Backend Test Runner</h3>
            <button onclick="runTestsAction()" class="px-4 py-2 bg-emerald-600 text-white font-bold text-xs rounded-xl">▶ Jalankan Test</button>
          </div>
        </div>
      `;
    }

    // ══════════════════════════════════════════════════════════════════════════
    // 4. 🎯 AGENTATION TOOLBAR & FLOATING INSPECTOR
    // ══════════════════════════════════════════════════════════════════════════
