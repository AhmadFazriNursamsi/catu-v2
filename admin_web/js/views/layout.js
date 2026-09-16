// ── Main Dashboard Layout & Navigation ──
    function toggleSidebar() {
      state.isSidebarOpen = !state.isSidebarOpen;
      localStorage.setItem('catu_sidebar_open', state.isSidebarOpen);
      renderApp();
    }

    // ══════════════════════════════════════════════════════════════════════════
    // 2. DASHBOARD MAIN LAYOUT & SIDEBAR (COLLAPSIBLE / TUTUP BUKA)
    // ══════════════════════════════════════════════════════════════════════════
    function renderDashboardLayout() {
      const adminName = state.currentUser?.fullName || state.currentUser?.full_name || 'Super Admin CATU';
      const pendingApprovalsCount = state.users.filter(u => (u.account_status || u.accountStatus) === 'PENDING_APPROVAL').length;
      const activeUmatCount = state.users.filter(u => (u.role_code || u.roleCode) === 'UMAT' && (u.account_status || u.accountStatus) === 'APPROVED').length;
      const activePengurusCount = state.users.filter(u => (u.role_code || u.roleCode) === 'PENGURUS_LINGKUNGAN' && (u.account_status || u.accountStatus) === 'APPROVED').length;
      const activeRomoParokiCount = state.users.filter(u => (u.role_code || u.roleCode) === 'ROMO_PAROKI' && (u.account_status || u.accountStatus) === 'APPROVED').length;
      const activeRomoOrdoCount = state.users.filter(u => (u.role_code || u.roleCode) === 'ROMO_ORDO' && (u.account_status || u.accountStatus) === 'APPROVED').length;
      const activeAnnotationsCount = state.agentation.annotations.filter(a => !a.resolved).length;
      const isOpen = state.isSidebarOpen !== false;

      return `
        <div class="h-full flex relative overflow-hidden">
          <!-- Sidebar Nav (Left) - Collapsible -->
          <div class="${isOpen ? 'w-64' : 'w-20'} bg-slate-900 border-r border-slate-800 flex flex-col justify-between flex-shrink-0 transition-all duration-300 ease-in-out">
            <div class="overflow-y-auto custom-scrollbar">
              <!-- Sidebar Header -->
              ${isOpen ? `
                <div class="p-5 flex items-center justify-between border-b border-slate-800">
                  <div class="flex items-center space-x-3">
                    <div class="w-9 h-9 rounded-xl bg-white p-1 shadow border border-amber-500 flex items-center justify-center flex-shrink-0">
                      <img src="assets/images/logoCatu.png" alt="CATU" class="h-full object-contain" />
                    </div>
                    <div>
                      <h2 class="text-sm font-extrabold text-white tracking-wide">CATU ADMIN</h2>
                      <p class="text-[9.5px] font-bold text-amber-400">PORTAL PUSAT SISTEM</p>
                    </div>
                  </div>
                  <button onclick="toggleSidebar()" class="p-1.5 rounded-lg text-slate-400 hover:bg-slate-800 hover:text-white transition" title="Tutup Sidebar">
                    <i data-lucide="chevron-left" class="w-4 h-4"></i>
                  </button>
                </div>
              ` : `
                <div class="p-3.5 flex flex-col items-center border-b border-slate-800 space-y-2">
                  <div class="w-10 h-10 rounded-xl bg-white p-1 shadow border border-amber-500 flex items-center justify-center flex-shrink-0">
                    <img src="assets/images/logoCatu.png" alt="CATU" class="h-full object-contain" />
                  </div>
                  <button onclick="toggleSidebar()" class="p-1 rounded-lg text-slate-400 hover:bg-slate-800 hover:text-white transition" title="Buka Sidebar">
                    <i data-lucide="chevron-right" class="w-4 h-4"></i>
                  </button>
                </div>
              `}

              <!-- Nav Items -->
              <nav class="${isOpen ? 'p-3 space-y-4' : 'p-2 space-y-3'}">
                <div>
                  ${isOpen ? `<p class="px-3 text-[10px] font-extrabold uppercase tracking-wider text-slate-500 mb-1.5">Utama</p>` : `<div class="h-px bg-slate-800 my-1 mx-2"></div>`}
                  <div class="space-y-1">
                    ${renderNavItem('overview', 'layout-dashboard', 'Ringkasan & Analytics')}
                    ${renderNavItem('orders', 'clipboard-list', 'Manajemen Pelayanan', state.analytics?.orders?.pending)}
                  </div>
                </div>

                <div>
                  ${isOpen ? `<p class="px-3 text-[10px] font-extrabold uppercase tracking-wider text-slate-500 mb-1.5">Pengguna Aktif</p>` : `<div class="h-px bg-slate-800 my-1 mx-2"></div>`}
                  <div class="space-y-1">
                    ${renderNavItem('umat', 'users', 'Umat Katolik', activeUmatCount, 'bg-blue-600')}
                    ${renderNavItem('pengurus', 'briefcase', 'Pengurus Lingkungan', activePengurusCount, 'bg-indigo-600')}
                    ${renderNavItem('romo_paroki', 'church', 'Romo Paroki', activeRomoParokiCount, 'bg-emerald-600')}
                    ${renderNavItem('romo_ordo', 'cross', 'Romo Ordo (On-Demand)', activeRomoOrdoCount, 'bg-purple-600')}
                  </div>
                </div>

                <div>
                  ${isOpen ? `<p class="px-3 text-[10px] font-extrabold uppercase tracking-wider text-slate-500 mb-1.5">Tata Kelola & Data</p>` : `<div class="h-px bg-slate-800 my-1 mx-2"></div>`}
                  <div class="space-y-1">
                    ${(pendingApprovalsCount > 0 || state.currentTab === 'approvals') ? renderNavItem('approvals', 'shield-check', 'Persetujuan Pendaftaran', pendingApprovalsCount, 'bg-amber-500') : ''}
                    ${renderNavItem('master', 'map-pin', 'Master Data Gereja')}
                    ${renderNavItem('chat', 'messages-square', 'Monitoring Chat')}
                    ${renderNavItem('qa', 'flask-conical', 'QA & Live Tests')}
                  </div>
                </div>
              </nav>
            </div>

            <!-- Sidebar Bottom Action Section -->
            ${isOpen ? `
              <div class="p-4 border-t border-slate-800 space-y-2">
                <button onclick="toggleAgentationMode()"
                  class="w-full py-2.5 px-3 rounded-xl ${state.agentation.enabled ? 'bg-amber-500 text-slate-950 font-black ring-2 ring-amber-300' : 'bg-slate-800 hover:bg-slate-700 text-amber-400 font-bold'} text-xs flex items-center justify-between transition shadow">
                  <div class="flex items-center space-x-2">
                    <i data-lucide="scan" class="w-4 h-4"></i>
                    <span>🎯 Agentation UI</span>
                  </div>
                  <span class="px-1.5 py-0.5 rounded-full text-[10px] ${state.agentation.enabled ? 'bg-slate-900 text-amber-400' : 'bg-amber-500/20 text-amber-400'} font-black">
                    ${activeAnnotationsCount}
                  </span>
                </button>

                <button id="logoutBtn" class="w-full py-2.5 px-3 rounded-xl bg-red-500/10 hover:bg-red-500/20 text-red-400 text-xs font-bold flex items-center space-x-2 transition">
                  <i data-lucide="log-out" class="w-4 h-4"></i>
                  <span>Keluar Akun Admin</span>
                </button>
              </div>
            ` : `
              <div class="p-2.5 border-t border-slate-800 space-y-2 flex flex-col items-center">
                <button onclick="toggleAgentationMode()" title="🎯 Agentation UI (${activeAnnotationsCount} catatan)"
                  class="w-11 h-11 rounded-xl relative flex items-center justify-center ${state.agentation.enabled ? 'bg-amber-500 text-slate-950 font-black ring-2 ring-amber-300' : 'bg-slate-800 hover:bg-slate-700 text-amber-400 font-bold'} text-xs transition shadow">
                  <i data-lucide="scan" class="w-5 h-5"></i>
                  ${activeAnnotationsCount > 0 ? `
                    <span class="absolute -top-1 -right-1 w-4 h-4 rounded-full bg-red-500 text-white text-[9px] font-black flex items-center justify-center ring-2 ring-slate-900">${activeAnnotationsCount}</span>
                  ` : ''}
                </button>

                <button id="logoutBtn" title="Keluar Akun Admin" class="w-11 h-11 rounded-xl bg-red-500/10 hover:bg-red-500/20 text-red-400 flex items-center justify-center transition">
                  <i data-lucide="log-out" class="w-5 h-5"></i>
                </button>
              </div>
            `}
          </div>

          <!-- Main Content View -->
          <div class="flex-1 flex flex-col overflow-hidden bg-slate-100 min-w-0">
            <header class="bg-white border-b border-slate-200 px-6 lg:px-8 py-4 flex items-center justify-between flex-shrink-0">
              <div class="flex items-center space-x-3">
                <button onclick="toggleSidebar()"
                  class="p-2 rounded-xl bg-slate-50 hover:bg-slate-100 border border-slate-200 text-slate-600 hover:text-blue-950 transition shadow-xs flex-shrink-0"
                  title="${isOpen ? 'Tutup Sidebar' : 'Buka Sidebar'}">
                  <i data-lucide="${isOpen ? 'panel-left-close' : 'panel-left-open'}" class="w-5 h-5"></i>
                </button>
                <div>
                  <p class="text-xs font-semibold text-slate-500">Admin Portal / <span class="text-blue-950 font-bold capitalize">${state.currentTab.replace('_', ' ')}</span></p>
                  <h1 class="text-xl font-extrabold text-slate-900 tracking-tight capitalize">${getTabTitle(state.currentTab)}</h1>
                </div>
              </div>

              <div class="flex items-center space-x-3 lg:space-x-4">
                <button onclick="toggleAgentationMode()"
                  class="flex items-center px-3 py-1.5 rounded-full text-xs font-bold transition ${
                    state.agentation.enabled ? 'bg-amber-500 text-slate-950 ring-2 ring-amber-300' : 'bg-amber-50 border border-amber-200 text-amber-800 hover:bg-amber-100'
                  }">
                  <span class="w-2 h-2 rounded-full ${state.agentation.enabled ? 'bg-slate-950 animate-ping' : 'bg-amber-500'} mr-2"></span>
                  ${state.agentation.enabled ? '🎯 Agentation Aktif' : '🎯 Mode Revisi UI'}
                </button>

                <div class="hidden sm:flex items-center px-3 py-1.5 rounded-full bg-emerald-50 border border-emerald-200 text-xs font-semibold text-emerald-800">
                  <span class="w-2 h-2 rounded-full bg-emerald-500 animate-pulse mr-2"></span>
                  Backend Online
                </div>

                <button id="refreshBtn" class="p-2 text-slate-600 hover:text-blue-950 rounded-lg hover:bg-slate-100 transition" title="Segarkan Data">
                  <i data-lucide="rotate-cw" class="w-4 h-4"></i>
                </button>

                <div class="flex items-center space-x-2.5 pl-3 lg:pl-4 border-l border-slate-200">
                  <div class="w-8 h-8 rounded-full bg-blue-950 text-white flex items-center justify-center font-bold text-xs shadow-xs">
                    SA
                  </div>
                  <div class="hidden md:block">
                    <p class="text-xs font-bold text-slate-900">${adminName}</p>
                    <p class="text-[10px] font-bold text-amber-600">SUPER ADMINISTRATOR</p>
                  </div>
                </div>
              </div>
            </header>

            <main class="flex-1 overflow-y-auto p-6 lg:p-8 custom-scrollbar relative" id="main-content-scroll">
              ${renderActiveTab()}
            </main>
          </div>
        </div>

        ${renderAgentationToolbar()}
        ${state.activeOrderDetail ? renderOrderDetailModal() : ''}
        ${state.activeChatOrder ? renderChatModal() : ''}
        ${state.activeUserProfile ? renderUserProfileModal() : ''}
        ${state.activeEditUser ? renderEditUserModal() : ''}
        ${state.activeMasterModal ? renderMasterModal() : ''}
        ${state.deleteConfirmModal ? renderDeleteConfirmModal() : ''}
        ${state.actionConfirmModal ? renderActionConfirmModal() : ''}
        ${state.agentation.pendingPin ? renderAgentationPendingDialog() : ''}
        ${renderToastsContainer()}
      `;
    }

    function renderNavItem(id, icon, label, badge, badgeColor = 'bg-red-500') {
      const active = state.currentTab === id;
      const isOpen = state.isSidebarOpen !== false;

      if (!isOpen) {
        return `
          <button onclick="setTab('${id}')" title="${label}"
            class="w-full relative flex items-center justify-center p-3 rounded-xl transition ${
              active ? 'bg-blue-950 text-amber-400 font-bold border border-blue-800 shadow-md' : 'text-slate-400 hover:bg-slate-800 hover:text-slate-200'
            }">
            <i data-lucide="${icon}" class="w-5 h-5 ${active ? 'text-amber-400' : ''}"></i>
            ${badge && parseInt(badge) > 0 ? `
              <span class="absolute top-1.5 right-1.5 w-2.5 h-2.5 rounded-full ${badgeColor} ring-2 ring-slate-900"></span>
            ` : ''}
          </button>
        `;
      }

      return `
        <button onclick="setTab('${id}')"
          class="w-full flex items-center justify-between px-3.5 py-2.5 rounded-xl text-xs font-semibold transition ${
            active ? 'bg-blue-950 text-white font-bold border border-blue-800' : 'text-slate-400 hover:bg-slate-800 hover:text-slate-200'
          }">
          <div class="flex items-center space-x-3">
            <i data-lucide="${icon}" class="w-4 h-4 ${active ? 'text-amber-400' : ''}"></i>
            <span class="truncate">${label}</span>
          </div>
          ${badge && parseInt(badge) > 0 ? `
            <span class="px-2 py-0.5 rounded-full text-[10px] font-bold text-white ${badgeColor}">${badge}</span>
          ` : ''}
        </button>
      `;
    }

    function getTabTitle(tab) {
      if (tab === 'overview') return 'Ringkasan & Analytics';
      if (tab === 'orders') return 'Manajemen Pelayanan';
      if (tab === 'umat') return 'Daftar Umat Katolik Aktif';
      if (tab === 'pengurus') return 'Daftar Pengurus Lingkungan Aktif';
      if (tab === 'romo_paroki') return 'Daftar Romo Paroki Aktif';
      if (tab === 'romo_ordo') return 'Daftar Romo Ordo Aktif (On-Demand)';
      if (tab === 'approvals') return 'Persetujuan Akun Pendaftaran Baru';
      if (tab === 'master') return 'Master Data Wilayah & Gereja';
      if (tab === 'chat') return 'Monitoring Group Chat Pelayanan';
      if (tab === 'qa') return 'QA & Live Test Runner';
      return tab;
    }

    function setTab(tab) {
      state.currentTab = tab;
      if (tab === 'master') {
        loadMasterData(state.masterSubTab || 'paroki');
      }
      renderApp();
    }

    function attachDashboardListeners() {
      const logoutBtn = document.getElementById('logoutBtn');
      if (logoutBtn) {
        logoutBtn.addEventListener('click', () => {
          localStorage.removeItem('catu_admin_user');
          localStorage.removeItem('catu_admin_token');
          state.currentUser = null;
          state.token = '';
          renderApp();
        });
      }

      const refreshBtn = document.getElementById('refreshBtn');
      if (refreshBtn) {
        refreshBtn.addEventListener('click', () => {
          loadDashboardData();
        });
      }
    }

    // ══════════════════════════════════════════════════════════════════════════
    // 3. TAB RENDERERS
    // ══════════════════════════════════════════════════════════════════════════