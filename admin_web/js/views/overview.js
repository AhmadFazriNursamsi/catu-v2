// ── Overview Dashboard & Monitoring Tab ──
    function renderOverviewCard(tab, icon, iconBg, count, title, subtitle, badgeText, badgeClass) {
      return `
        <div class="bg-white rounded-2xl p-5 border border-slate-200 shadow-xs cursor-pointer hover:border-blue-900/40 hover:shadow-md transition flex flex-col justify-between" onclick="setTab('${tab}')">
          <div>
            <div class="flex items-center justify-between mb-3">
              <div class="w-10 h-10 rounded-xl ${iconBg} flex items-center justify-center font-bold">
                <i data-lucide="${icon}" class="w-5 h-5"></i>
              </div>
              <span class="text-[11px] font-bold px-2.5 py-0.5 rounded-full ${badgeClass}">
                ${badgeText}
              </span>
            </div>
            <h3 class="text-2xl font-extrabold text-slate-900">${count}</h3>
            <p class="text-xs font-bold text-slate-800 mt-1">${title}</p>
          </div>
          <p class="text-[11px] font-medium text-slate-500 mt-2">${subtitle}</p>
        </div>
      `;
    }

    function renderOverviewTab() {
      const isSuper = typeof isSuperAdminUser === 'function' && isSuperAdminUser();
      const orders = state.analytics?.orders || {};
      const users = state.analytics?.users || {};
      const totalOrders = state.orders?.length || orders.total || 0;
      const pendingOrders = (state.orders || []).filter(o => getEffectiveOrderStatus(o) === 'PENDING').length;

      const pendingUsers = (state.users || []).filter(u => (u.account_status || u.accountStatus) === 'PENDING_APPROVAL').length;
      const isPureUmat = u => {
        const r = (u.role_code || u.roleCode || '').toUpperCase();
        const pos = (u.pengurus_position || '').trim();
        const isPengurusOrKoor = r === 'PENGURUS_LINGKUNGAN' || r.includes('KOORDINATOR') || pos.length > 0;
        return r === 'UMAT' && !isPengurusOrKoor && (u.account_status || u.accountStatus) === 'APPROVED';
      };
      const totalUmat = (state.users || []).filter(isPureUmat).length || 0;
      const totalUmatPendatang = (state.users || []).filter(u => (u.role_code || u.roleCode) === 'UMAT_PENDATANG' && (u.account_status || u.accountStatus) === 'APPROVED').length || 0;

      const isPurePengurus = u => {
        const r = (u.role_code || u.roleCode || '').toUpperCase();
        const pos = (u.pengurus_position || '').toLowerCase();
        return (r === 'PENGURUS_LINGKUNGAN' || (pos.length > 0 && !pos.includes('koordinator'))) && !r.includes('KOORDINATOR') && (u.account_status || u.accountStatus) === 'APPROVED';
      };
      const totalPengurus = (state.users || []).filter(isPurePengurus).length || 0;

      const isKoordinator = u => {
        const r = (u.role_code || u.roleCode || '').toUpperCase();
        const pos = (u.pengurus_position || '').toLowerCase();
        return (r.includes('KOORDINATOR') || pos.includes('koordinator')) && (u.account_status || u.accountStatus) === 'APPROVED';
      };
      const totalKoordinator = (state.users || []).filter(isKoordinator).length || 0;

      const totalRomoParoki = (state.users || []).filter(u => (u.role_code || u.roleCode) === 'ROMO_PAROKI' && (u.account_status || u.accountStatus) === 'APPROVED').length || users.total_romo_paroki || 0;
      const totalRomoOrdo = (state.users || []).filter(u => (u.role_code || u.roleCode) === 'ROMO_ORDO' && (u.account_status || u.accountStatus) === 'APPROVED').length || users.total_romo_ordo || 0;

      const totalParoki = (state.paroki || []).length;
      const totalKeuskupan = (state.keuskupan || []).length;

      return `
        <div class="space-y-6">
          <!-- Page Header -->
          <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-2 pb-1">
            <div>
              <h2 class="text-xl font-extrabold text-slate-900 tracking-tight">Dashboard</h2>
              <p class="text-xs text-slate-500 mt-0.5">Pemantauan menyeluruh seluruh modul dan fitur pelayanan pastoral.</p>
            </div>
          </div>

          <!-- Feature KPI Cards Grid -->
          <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-3.5 sm:gap-5">
            ${renderOverviewCard('orders', 'clipboard-list', 'bg-blue-50 text-blue-900', totalOrders, 'Daftar Pelayanan', 'Permohonan sakramen pastoral', `${pendingOrders} Menunggu`, pendingOrders > 0 ? 'bg-amber-50 text-amber-800 border border-amber-200' : 'bg-slate-100 text-slate-600')}
            ${renderOverviewCard('approvals', 'shield-check', 'bg-amber-50 text-amber-800', pendingUsers, 'Persetujuan Pendaftaran', 'Verifikasi pendaftaran pengguna', pendingUsers > 0 ? `${pendingUsers} Verifikasi` : 'Semua Disetujui', pendingUsers > 0 ? 'bg-amber-50 text-amber-800 border border-amber-200' : 'bg-emerald-50 text-emerald-800 border border-emerald-200')}
            ${renderOverviewCard('umat', 'users', 'bg-indigo-50 text-indigo-900', totalUmat, 'Umat Katolik', 'Warga paroki terdaftar aktif', 'Warga Paroki', 'bg-indigo-50 text-indigo-800 border border-indigo-200')}
            ${renderOverviewCard('umat_pendatang', 'map-pin', 'bg-emerald-50 text-emerald-800', totalUmatPendatang, 'Umat Pendatang', 'Umat tamu & kunjungan beribadah', 'Kunjungan', 'bg-emerald-50 text-emerald-800 border border-emerald-200')}
            ${renderOverviewCard('pengurus', 'briefcase', 'bg-sky-50 text-sky-800', totalPengurus, 'Pengurus Lingkungan', 'Pengurus lingkungan paroki', 'Lingkungan', 'bg-sky-50 text-sky-800 border border-sky-200')}
            ${renderOverviewCard('koordinator', 'award', 'bg-cyan-50 text-cyan-800', totalKoordinator, 'Koordinator Keuskupan', 'Koordinator resmi keuskupan', 'Keuskupan', 'bg-cyan-50 text-cyan-800 border border-cyan-200')}
            ${renderOverviewCard('romo_paroki', 'church', 'bg-amber-50 text-amber-800', totalRomoParoki, 'Romo Paroki', 'Pastor paroki siap bertugas', 'Diosesan', 'bg-amber-50 text-amber-800 border border-amber-200')}
            ${renderOverviewCard('romo_ordo', 'cross', 'bg-purple-50 text-purple-800', totalRomoOrdo, 'Romo Ordo', 'Pastor kongregasi / ordo', 'Ordo', 'bg-purple-50 text-purple-800 border border-purple-200')}
            ${renderOverviewCard('master', 'database', 'bg-slate-100 text-slate-700', totalParoki, 'Master Data', `${totalKeuskupan} Keuskupan terdaftar`, 'Paroki & Wilayah', 'bg-blue-50 text-blue-800 border border-blue-200')}
            ${isSuper ? renderOverviewCard('activity_logs', 'scroll-text', 'bg-rose-50 text-rose-800', 'Audit', 'Log Aktivitas', 'Audit trail operasional sistem', 'Keamanan', 'bg-rose-50 text-rose-800 border border-rose-200') : ''}
            ${isSuper ? renderOverviewCard('settings', 'download', 'bg-teal-50 text-teal-800', 'APK', 'Download Apps', 'Distribusi aplikasi mobile CATU', 'Hanya Android', 'bg-teal-50 text-teal-800 border border-teal-200') : ''}
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
