// ── Main Dashboard Layout & Navigation ──
    function toggleSidebar() {
      state.isSidebarOpen = !state.isSidebarOpen;
      localStorage.setItem('catu_sidebar_open', state.isSidebarOpen);
      renderApp();
    }

    function toggleMobileMenu() {
      state.isMobileMenuOpen = !state.isMobileMenuOpen;
      renderApp();
    }

    function closeMobileMenu() {
      if (state.isMobileMenuOpen) {
        state.isMobileMenuOpen = false;
        renderApp();
      }
    }

    // ══════════════════════════════════════════════════════════════════════════
    // 2. DASHBOARD MAIN LAYOUT & SIDEBAR (COLLAPSIBLE / TUTUP BUKA)
    // ══════════════════════════════════════════════════════════════════════════
    function renderSidebarHeader(isOpen) {
      return `
        <div class="${isOpen ? 'p-4 sm:p-5' : 'p-3.5'} flex items-center justify-between border-b border-slate-800">
          <div class="flex items-center space-x-3">
            <div class="w-9 h-9 rounded-xl bg-white p-1 shadow border border-blue-500/60 flex items-center justify-center flex-shrink-0">
              <img src="assets/images/logoCatu.png" alt="CATU" class="h-full object-contain" />
            </div>
            ${isOpen ? `
              <div>
                <h2 class="text-sm font-extrabold text-white tracking-wide">CATU</h2>
                <p class="text-[9px] font-bold text-blue-300 tracking-wider">PELAYANAN PASTORAL</p>
              </div>
            ` : ''}
          </div>
          <button onclick="closeMobileMenu()" class="p-1.5 text-slate-400 hover:text-white rounded-lg lg:hidden transition" aria-label="Tutup Menu">
            <i data-lucide="x" class="w-5 h-5"></i>
          </button>
        </div>
      `;
    }

    function renderSidebarBottom(isOpen, adminName, activeAnnotationsCount) {
      const isSuper = typeof isSuperAdminUser === 'function' && isSuperAdminUser();
      const roleLabel = isSuper ? 'Super Administrator' : 'Administrator';
      const initials = (adminName || 'Admin').substring(0, 2).toUpperCase();
      if (isOpen) {
        return `
          <div class="p-3 border-t border-slate-800 space-y-2">
            <!-- User Profile Info -->
            <div class="flex items-center space-x-3 p-2.5 rounded-xl bg-slate-800/60 border border-slate-700/50">
              <div class="w-9 h-9 rounded-full bg-blue-950 text-white flex items-center justify-center font-bold text-xs shadow-xs flex-shrink-0 border border-blue-500/40">
                ${initials}
              </div>
              <div class="min-w-0 flex-1">
                <p class="text-xs font-bold text-slate-200 truncate">${adminName}</p>
                <p class="text-[9px] font-bold text-blue-400 uppercase tracking-wider">${roleLabel}</p>
              </div>
            </div>

            ${AGENTATION_ENABLED ? `
            <button onclick="toggleAgentationMode()"
              class="w-full py-2.5 px-3 rounded-xl ${state.agentation.enabled ? 'bg-blue-600 text-white font-bold ring-2 ring-blue-400' : 'bg-slate-800 hover:bg-slate-700 text-slate-300 font-bold'} text-xs flex items-center justify-between transition shadow">
              <div class="flex items-center space-x-2">
                <i data-lucide="scan" class="w-4 h-4"></i>
                <span>🎯 Agentation UI</span>
              </div>
              <span class="px-1.5 py-0.5 rounded-full text-[10px] ${state.agentation.enabled ? 'bg-blue-900 text-white' : 'bg-blue-500/20 text-blue-300'} font-bold">
                ${activeAnnotationsCount}
              </span>
            </button>
            ` : ''}

            <button id="logoutBtn" class="w-full py-2.5 px-3 rounded-xl bg-red-500/10 hover:bg-red-500/20 text-red-400 text-xs font-bold flex items-center space-x-2 transition">
              <i data-lucide="log-out" class="w-4 h-4"></i>
              <span>Keluar Akun Admin</span>
            </button>

            <!-- Toggle Sidebar Button (Paling Bawah) -->
            <button onclick="toggleSidebar()" class="w-full py-2 px-3 rounded-xl bg-slate-800/80 hover:bg-slate-700 text-slate-400 hover:text-white text-xs font-semibold flex items-center justify-center space-x-2 transition" title="Tutup Sidebar">
              <i data-lucide="chevron-left" class="w-4 h-4"></i>
              <span>Tutup Sidebar</span>
            </button>
          </div>
        `;
      }

      return `
        <div class="p-2.5 border-t border-slate-800 space-y-2 flex flex-col items-center">
          <div class="w-9 h-9 rounded-full bg-blue-950 text-white flex items-center justify-center font-bold text-xs shadow-xs border border-blue-500/40" title="${adminName} (${roleLabel})">
            ${initials}
          </div>

          ${AGENTATION_ENABLED ? `
          <button onclick="toggleAgentationMode()" title="🎯 Agentation UI (${activeAnnotationsCount} catatan)"
            class="w-11 h-11 rounded-xl relative flex items-center justify-center ${state.agentation.enabled ? 'bg-blue-600 text-white font-bold ring-2 ring-blue-400' : 'bg-slate-800 hover:bg-slate-700 text-slate-300 font-bold'} text-xs transition shadow">
            <i data-lucide="scan" class="w-5 h-5"></i>
            ${activeAnnotationsCount > 0 ? `
              <span class="absolute -top-1 -right-1 w-4 h-4 rounded-full bg-blue-900 text-white text-[9px] font-black flex items-center justify-center ring-2 ring-slate-900">${activeAnnotationsCount}</span>
            ` : ''}
          </button>
          ` : ''}

          <button id="logoutBtn" title="Keluar Akun Admin" class="w-11 h-11 rounded-xl bg-red-500/10 hover:bg-red-500/20 text-red-400 flex items-center justify-center transition">
            <i data-lucide="log-out" class="w-5 h-5"></i>
          </button>

          <!-- Toggle Sidebar Button (Paling Bawah) -->
          <button onclick="toggleSidebar()" title="Buka Sidebar" class="w-11 h-11 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-400 hover:text-white flex items-center justify-center transition">
            <i data-lucide="chevron-right" class="w-5 h-5"></i>
          </button>
        </div>
      `;
    }

    function renderDashboardLayout() {
      const adminName = state.currentUser?.fullName || state.currentUser?.full_name || 'Super Admin CATU';
      const pendingApprovalsCount = state.users.filter(u => (u.account_status || u.accountStatus) === 'PENDING_APPROVAL').length;
      const activeUmatCount = state.users.filter(u => (u.role_code || u.roleCode) === 'UMAT' && (u.account_status || u.accountStatus) === 'APPROVED').length;
      const activeUmatPendatangCount = state.users.filter(u => (u.role_code || u.roleCode) === 'UMAT_PENDATANG' && (u.account_status || u.accountStatus) === 'APPROVED').length;
      const isPengurusOrKoordinator = u => {
        const r = (u.role_code || u.roleCode || '').toUpperCase();
        const pos = (u.pengurus_position || '').toLowerCase();
        return (r === 'PENGURUS_LINGKUNGAN' || pos.includes('koordinator') || r.includes('KOORDINATOR')) && (u.account_status || u.accountStatus) === 'APPROVED';
      };
      const activePengurusCount = state.users.filter(isPengurusOrKoordinator).length;
      const activeRomoParokiCount = state.users.filter(u => (u.role_code || u.roleCode) === 'ROMO_PAROKI' && (u.account_status || u.accountStatus) === 'APPROVED').length;
      const activeRomoOrdoCount = state.users.filter(u => (u.role_code || u.roleCode) === 'ROMO_ORDO' && (u.account_status || u.accountStatus) === 'APPROVED').length;
      const activeAnnotationsCount = AGENTATION_ENABLED ? state.agentation.annotations.filter(a => !a.resolved).length : 0;
      const isOpen = state.isSidebarOpen !== false;
      const isMobileOpen = Boolean(state.isMobileMenuOpen);

      return `
        <div class="h-full flex relative overflow-hidden">
          <!-- Mobile Backdrop Overlay -->
          ${isMobileOpen ? `
            <div onclick="closeMobileMenu()" class="fixed inset-0 bg-slate-950/60 backdrop-blur-xs z-40 lg:hidden transition-opacity"></div>
          ` : ''}

          <!-- Sidebar Nav (Left) - Drawer on mobile, Collapsible on desktop -->
          <aside class="fixed inset-y-0 left-0 z-50 ${isMobileOpen ? 'translate-x-0 shadow-2xl' : '-translate-x-full'} lg:translate-x-0 lg:static lg:z-auto ${isOpen ? 'w-64' : 'w-20'} bg-slate-900 border-r border-slate-800 flex flex-col justify-between flex-shrink-0 transition-all duration-300 ease-in-out">
            <div class="overflow-y-auto custom-scrollbar">
              <!-- Sidebar Header -->
              ${renderSidebarHeader(isOpen || isMobileOpen)}

              <!-- Nav Items -->
              <nav class="${(isOpen || isMobileOpen) ? 'p-3 space-y-4' : 'p-2 space-y-3'}">
                <div>
                  ${(isOpen || isMobileOpen) ? `<p class="px-3 text-[10px] font-extrabold uppercase tracking-wider text-slate-500 mb-1.5">Pelayanan Pastoral</p>` : `<div class="h-px bg-slate-800 my-1 mx-2"></div>`}
                  <div class="space-y-1">
                    ${renderNavItem('overview', 'layout-dashboard', 'Ringkasan Pastoral')}
                    ${renderNavItem('orders', 'clipboard-list', 'Permohonan Sakramen', (state.orders || []).filter(o => getEffectiveOrderStatus(o) === 'PENDING').length, 'bg-blue-600')}
                  </div>
                </div>

                <div>
                  ${(isOpen || isMobileOpen) ? `<p class="px-3 text-[10px] font-extrabold uppercase tracking-wider text-slate-500 mb-1.5">Data Keumatan</p>` : `<div class="h-px bg-slate-800 my-1 mx-2"></div>`}
                  <div class="space-y-1">
                    ${renderNavItem('umat', 'users', 'Umat Katolik', activeUmatCount, 'bg-blue-600')}
                    ${renderNavItem('umat_pendatang', 'map-pin', 'Umat Pendatang', activeUmatPendatangCount, 'bg-blue-600')}
                    ${renderNavItem('pengurus', 'briefcase', 'Pengurus Lingkungan', activePengurusCount, 'bg-blue-600')}
                    ${renderNavItem('romo_paroki', 'church', 'Romo Paroki', activeRomoParokiCount, 'bg-blue-600')}
                    ${renderNavItem('romo_ordo', 'cross', 'Romo Ordo', activeRomoOrdoCount, 'bg-blue-600')}
                  </div>
                </div>

                <div>
                  ${(isOpen || isMobileOpen) ? `<p class="px-3 text-[10px] font-extrabold uppercase tracking-wider text-slate-500 mb-1.5">Tata Kelola & Wilayah</p>` : `<div class="h-px bg-slate-800 my-1 mx-2"></div>`}
                  <div class="space-y-1">
                    ${(pendingApprovalsCount > 0 || state.currentTab === 'approvals') ? renderNavItem('approvals', 'shield-check', 'Persetujuan Pendaftaran', pendingApprovalsCount, 'bg-blue-600') : ''}
                    ${renderNavItem('master', 'database', 'Master Data')}
                    ${typeof isSuperAdminUser === 'function' && isSuperAdminUser() ? renderNavItem('activity_logs', 'scroll-text', 'Log Aktivitas') : ''}
                    ${typeof isSuperAdminUser === 'function' && isSuperAdminUser() ? renderNavItem('settings', 'settings', 'Pengaturan Portal') : ''}
                  </div>
                </div>
              </nav>
            </div>

            <!-- Sidebar Bottom Action Section -->
            ${renderSidebarBottom(isOpen || isMobileOpen, adminName, activeAnnotationsCount)}
          </aside>

          <!-- Main Content View -->
          <div class="flex-1 flex flex-col overflow-hidden bg-slate-100 min-w-0">
            <header class="bg-white border-b border-slate-200 px-4 py-3 sm:px-6 lg:px-8 sm:py-4 flex items-center justify-between flex-shrink-0">
              <div class="flex items-center space-x-2.5 min-w-0">
                <button onclick="toggleMobileMenu()" class="p-2 -ml-1.5 rounded-xl text-slate-700 hover:text-slate-900 hover:bg-slate-100 transition lg:hidden" aria-label="Buka Menu Navigasi">
                  <i data-lucide="menu" class="w-5 h-5"></i>
                </button>
                <h1 class="text-base sm:text-xl font-extrabold text-slate-900 tracking-tight truncate">${getTabTitle(state.currentTab)}</h1>
              </div>
              <div class="flex items-center space-x-2">
                <button id="refreshBtn" class="p-2 rounded-xl text-slate-600 hover:text-slate-900 hover:bg-slate-100 transition" title="Muat Ulang Data">
                  <i data-lucide="rotate-cw" class="w-4 h-4"></i>
                </button>
              </div>
            </header>

            <main class="flex-1 overflow-y-auto p-3.5 sm:p-6 lg:p-8 custom-scrollbar relative" id="main-content-scroll">
              ${renderActiveTab()}
            </main>
          </div>
        </div>

        ${AGENTATION_ENABLED ? renderAgentationToolbar() : ''}
        ${state.activeOrderDetail ? renderOrderDetailModal() : ''}
        ${state.activeChatOrder ? renderChatModal() : ''}
        ${state.activeUserProfile ? renderUserProfileModal() : ''}
        ${state.activeEditUser ? renderEditUserModal() : ''}
        ${state.activeMasterModal ? renderMasterModal() : ''}
        ${state.deleteConfirmModal ? renderDeleteConfirmModal() : ''}
        ${state.actionConfirmModal ? renderActionConfirmModal() : ''}
        ${state.activeLogDetailModal && typeof renderActivityLogDetailModal === 'function' ? renderActivityLogDetailModal() : ''}
        ${AGENTATION_ENABLED && state.agentation.pendingPin ? renderAgentationPendingDialog() : ''}
        ${renderToastsContainer()}
      `;
    }

    function renderNavItem(id, icon, label, badge, badgeColor = 'bg-blue-600') {
      const active = state.currentTab === id;
      const isOpen = (state.isSidebarOpen !== false) || Boolean(state.isMobileMenuOpen);

      if (!isOpen) {
        return `
          <button onclick="setTab('${id}')" title="${label}"
            class="w-full relative flex items-center justify-center p-3 rounded-xl transition ${
              active ? 'bg-blue-950/80 text-blue-400 font-bold border-l-2 border-blue-500 shadow-md' : 'text-slate-400 hover:bg-slate-800 hover:text-slate-200'
            }">
            <i data-lucide="${icon}" class="w-5 h-5 ${active ? 'text-blue-400' : ''}"></i>
            ${badge && parseInt(badge) > 0 ? `
              <span class="absolute top-1.5 right-1.5 w-2.5 h-2.5 rounded-full ${badgeColor} ring-2 ring-slate-900"></span>
            ` : ''}
          </button>
        `;
      }

      return `
        <button onclick="setTab('${id}')"
          class="w-full flex items-center justify-between px-3.5 py-2.5 rounded-xl text-xs font-semibold transition ${
            active ? 'bg-blue-950/80 text-white font-bold border-l-2 border-blue-500 shadow-xs' : 'text-slate-400 hover:bg-slate-800 hover:text-slate-200'
          }">
          <div class="flex items-center space-x-3">
            <i data-lucide="${icon}" class="w-4 h-4 ${active ? 'text-blue-400' : ''}"></i>
            <span class="truncate">${label}</span>
          </div>
          ${badge && parseInt(badge) > 0 ? `
            <span class="px-2 py-0.5 rounded-full text-[10px] font-bold text-white ${badgeColor}">${badge}</span>
          ` : ''}
        </button>
      `;
    }

    function getTabTitle(tab) {
      if (tab === 'overview') return 'Ringkasan Pastoral';
      if (tab === 'orders') return 'Permohonan Pelayanan Sakramen';
      if (tab === 'umat') return 'Data Umat Katolik';
      if (tab === 'umat_pendatang') return 'Data Umat Pendatang';
      if (tab === 'pengurus') return 'Data Pengurus Lingkungan';
      if (tab === 'romo_paroki') return 'Data Romo Paroki';
      if (tab === 'romo_ordo') return 'Data Romo Ordo';
      if (tab === 'approvals') return 'Persetujuan Pendaftaran Akun';
      if (tab === 'master') return 'Master Data';
      if (tab === 'activity_logs') return 'Log Aktivitas & Audit Trail';
      if (tab === 'chat') return 'Monitoring Komunikasi Chat';
      if (tab === 'settings') return 'Pengaturan Portal';
      return tab;
    }

    function setTab(tab) {
      if ((tab === 'activity_logs' || tab === 'settings') && (typeof isSuperAdminUser === 'function' && !isSuperAdminUser())) {
        if (typeof showToast === 'function') showToast('warning', 'Akses terbatas: Menu ini hanya dapat diakses oleh Super Admin.');
        state.currentTab = 'overview';
        state.isMobileMenuOpen = false;
        renderApp();
        return;
      }
      state.currentTab = tab;
      state.isMobileMenuOpen = false;
      if (tab === 'master') {
        loadMasterData(state.masterSubTab || 'paroki');
      }
      if (tab === 'activity_logs') {
        loadActivityLogs(1);
      }
      renderApp();
    }

    function attachDashboardListeners() {
      const logoutBtn = document.getElementById('logoutBtn');
      if (logoutBtn) {
        logoutBtn.addEventListener('click', async () => {
          try {
            if (state.token) {
              await fetch(`${API_BASE}/auth/admin/logout`, {
                method: 'POST',
                headers: {
                  'Content-Type': 'application/json',
                  Authorization: `Bearer ${state.token}`,
                },
                body: JSON.stringify({
                  userId: state.currentUser?.id,
                  fullName: state.currentUser?.fullName || state.currentUser?.full_name,
                }),
              });
            }
          } catch (_) {}
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

      if (state.currentTab === 'settings' && typeof initializeSettingsView === 'function') {
        initializeSettingsView();
      }
    }

    // ══════════════════════════════════════════════════════════════════════════
    // 3. TAB RENDERERS
    // ══════════════════════════════════════════════════════════════════════════
