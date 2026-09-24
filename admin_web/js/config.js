// ── Global Config, State & Utility Badges ──
    const CATU_NODE_ENV = window.CATU_RUNTIME_CONFIG?.nodeEnv || 'production';
    const AGENTATION_ENABLED = CATU_NODE_ENV !== 'production';

    // Config & State
    const configuredApiBase = window.CATU_RUNTIME_CONFIG?.apiBaseUrl?.trim();
    const isLocalHost = window.location.hostname === 'localhost' ||
                        window.location.hostname === '127.0.0.1' ||
                        window.location.hostname.startsWith('10.') ||
                        window.location.hostname.startsWith('192.168.') ||
                        window.location.hostname.endsWith('.local');
    const defaultApiBase = isLocalHost ? `http://${window.location.hostname}:3005` : window.location.origin;
    const API_BASE = (configuredApiBase || defaultApiBase).replace(/\/+$/, '');
    const configuredApkDownloadUrl = window.CATU_RUNTIME_CONFIG?.apkDownloadUrl?.trim();
    const APK_DOWNLOAD_URL = (configuredApkDownloadUrl || '').replace(/\/+$/, '');
    let rawStoredUser = null;
    try {
      rawStoredUser = JSON.parse(localStorage.getItem('catu_admin_user') || 'null');
    } catch(e) { rawStoredUser = null; }

    // Load persisted Agentation annotations
    let rawStoredAnnotations = [];
    if (AGENTATION_ENABLED) {
      try {
        rawStoredAnnotations = JSON.parse(localStorage.getItem('catu_agentation_annotations') || '[]');
      } catch(e) { rawStoredAnnotations = []; }
    }

    function isSuperAdminUser() {
      const role = (state?.currentUser?.roleCode || state?.currentUser?.role_code || '').toUpperCase();
      return role === 'SUPERADMIN';
    }

    function isAnyAdminUser(u) {
      const role = (u?.roleCode || u?.role_code || '').toUpperCase();
      return role === 'ADMIN' || role === 'SUPERADMIN';
    }

    const state = {
      currentUser: (rawStoredUser && isAnyAdminUser(rawStoredUser)) ? rawStoredUser : null,
      token: localStorage.getItem('catu_admin_token') || '',
      currentTab: 'overview',
      isSidebarOpen: localStorage.getItem('catu_sidebar_open') !== 'false',
      isMobileMenuOpen: false,
      analytics: null,
      orders: [],
      users: [],
      provinsi: [],
      kabupatenKota: [],
      keuskupan: [],
      paroki: [],
      wilayah: [],
      lingkungan: [],
      ordo: [],
      roles: [],
      positions: [],
      masterSubTab: 'paroki',
      masterSearch: '',
      masterFilterKeuskupanId: '',
      masterFilterParokiId: '',
      masterFilterWilayahId: '',
      serviceCategories: [],
      masterDataList: [],
      isMasterLoading: false,
      activeMasterModal: null,
      modalParokiList: [],
      modalWilayahList: [],
      isSavingMaster: false,
      masterModalError: '',
      deleteConfirmModal: null,
      
      // Searches
      orderSearch: '',
      orderStatusFilter: 'ALL',
      orderCategoryFilter: 'ALL',
      
      umatSearch: '',
      umatFilterParoki: '',
      umatFilterLingkungan: '',

      umatPendatangSearch: '',
      umatPendatangFilterKeuskupan: '',
      umatPendatangFilterParoki: '',

      pengurusSearch: '',
      pengurusFilterPosition: '',
      pengurusFilterParoki: '',

      romoParokiSearch: '',
      romoParokiFilterPosition: '',
      romoParokiFilterParoki: '',

      romoOrdoSearch: '',
      romoOrdoFilterOrdo: '',
      romoOrdoFilterPosition: '',

      approvalsSearch: '',
      approvalsFilterRole: '',
      approvalsFilterParoki: '',

      isLoading: false,
      loginLoading: false,
      loginError: '',
      testResults: null,
      isRunningTests: false,

      // Activity Logs State
      activityLogs: [],
      activityLogsLoading: false,
      activityLogsPage: 1,
      activityLogsLimit: 20,
      activityLogsTotal: 0,
      activityLogsTotalPages: 1,
      activityLogsSearch: '',
      activityLogsFilterRole: '',
      activityLogsFilterAction: '',
      activityLogsFilterEntity: '',
      activeLogDetailModal: null,
      
      // Modals
      activeChatOrder: null,
      activeOrderDetail: null,
      activeUserProfile: null,
      activeEditUser: null,
      editKabupatenKotaList: [],
      editParokiList: [],
      editWilayahList: [],
      editLingkunganList: [],
      comboboxFilters: {},
      openCombobox: null,
      isSavingProfile: false,
      editFormError: '',
      toasts: [],
      actionConfirmModal: null,

      // 🎯 Agentation Visual Feedback System State
      agentation: {
        enabled: false,
        expanded: false,
        showDrawer: false,
        annotations: AGENTATION_ENABLED ? rawStoredAnnotations : [],
        pendingPin: null,
        activePinId: null,
        selectedCategory: 'BUG',
      }
    };

    function showToast(message, type = 'success', title = '', duration = 4000) {
      const id = 'toast_' + Date.now() + '_' + Math.random().toString(36).substr(2, 5);
      const defaultTitles = {
        success: 'Aksi Berhasil',
        error: 'Terjadi Kesalahan',
        warning: 'Pemberitahuan',
        info: 'Informasi'
      };
      
      const toastObj = {
        id,
        message,
        type,
        title: title || defaultTitles[type] || 'Notifikasi',
        timestamp: Date.now()
      };

      state.toasts.push(toastObj);
      renderApp();

      if (duration > 0) {
        setTimeout(() => {
          dismissToast(id);
        }, duration);
      }
    }

    function dismissToast(id) {
      state.toasts = state.toasts.filter(t => t.id !== id);
      renderApp();
    }

    function getMasterEntityLabel(s) {
      if (s === 'keuskupan') return 'Keuskupan';
      if (s === 'paroki') return 'Paroki';
      if (s === 'wilayah') return 'Wilayah';
      if (s === 'lingkungan') return 'Lingkungan';
      if (s === 'ordo') return 'Ordo / Kongregasi';
      if (s === 'services') return 'Kategori Pelayanan';
      if (s === 'roles') return 'Jenis User / Peran Pengguna';
      if (s === 'positions') return 'Jabatan & Struktur Pengurus / Romo';
      return s || 'Data Master';
    }
    window.getMasterEntityLabel = getMasterEntityLabel;
    window.getEntityLabel = getMasterEntityLabel;

    function renderToastsContainer() {
      if (!state.toasts || state.toasts.length === 0) return '';
      return `
        <div class="fixed bottom-6 right-6 z-[99999] flex flex-col space-y-3 pointer-events-none max-w-sm w-full">
          ${state.toasts.map(toast => {
            const isSuccess = toast.type === 'success';
            const isError = toast.type === 'error';
            const isWarning = toast.type === 'warning';
            
            const borderBg = isSuccess ? 'border-emerald-200 bg-white' :
              isError ? 'border-rose-200 bg-white' :
              isWarning ? 'border-amber-200 bg-white' :
              'border-blue-200 bg-white';

            const iconBg = isSuccess ? 'bg-emerald-50 text-emerald-700' :
              isError ? 'bg-rose-50 text-rose-700' :
              isWarning ? 'bg-amber-50 text-amber-700' :
              'bg-blue-50 text-blue-700';

            const iconName = isSuccess ? 'check-circle-2' : isError ? 'alert-octagon' : isWarning ? 'alert-triangle' : 'info';
            const titleColor = isSuccess ? 'text-emerald-950' : isError ? 'text-rose-950' : isWarning ? 'text-amber-950' : 'text-blue-950';

            return `
              <div class="pointer-events-auto bg-white rounded-2xl shadow-2xl ${borderBg} border p-4 flex items-start space-x-3.5 transform transition-all duration-300 shadow-xl shadow-slate-900/10 ring-1 ring-black/5">
                <div class="w-10 h-10 rounded-xl flex items-center justify-center flex-shrink-0 ${iconBg}">
                  <i data-lucide="${iconName}" class="w-5 h-5"></i>
                </div>
                <div class="flex-1 min-w-0 pt-0.5">
                  <h4 class="font-black text-xs ${titleColor} tracking-tight">${toast.title}</h4>
                  <p class="text-xs font-semibold text-slate-700 mt-0.5 leading-relaxed">${toast.message}</p>
                </div>
                <button onclick="dismissToast('${toast.id}')" class="text-slate-400 hover:text-slate-700 p-1 rounded-lg hover:bg-slate-100 transition flex-shrink-0" title="Tutup">
                  <i data-lucide="x" class="w-3.5 h-3.5"></i>
                </button>
              </div>
            `;
          }).join('')}
        </div>
      `;
    }


    function getStatusBadgeClass(status) {
      const s = (status || '').toUpperCase();
      if (s === 'CONFIRMED' || s === 'ACCEPTED' || s === 'COMPLETED' || s === 'APPROVED' || s === 'AKTIF') {
        return 'bg-emerald-50 text-emerald-800 border border-emerald-200';
      }
      if (s === 'DONE' || s === 'VERIFIED') {
        return 'bg-blue-50 text-blue-800 border border-blue-200';
      }
      if (s === 'ROMO_ASSIGNED' || s === 'PROCESS' || s === 'ASSIGNED') {
        return 'bg-blue-50 text-blue-800 border border-blue-200';
      }
      if (s === 'FAIL' || s === 'REJECTED' || s === 'CANCELLED' || s === 'TIDAK AKTIF') {
        return 'bg-rose-50 text-rose-800 border border-rose-200';
      }
      return 'bg-amber-50 text-amber-800 border border-amber-200';
    }

    function getUserPositionBadge(pos, roleCode) {
      let p = (pos || '').trim();
      const r = (roleCode || '').toUpperCase();

      if (r === 'ROMO_ORDO') {
        if (p.toLowerCase().includes('ketua') || p.toUpperCase() === 'KETUA_ROMO') p = 'Ketua Romo Ordo';
        else if (p.toUpperCase() === 'ROMO_BIASA' || !p) p = 'Romo Ordo';
      } else if (r === 'ROMO_PAROKI') {
        if (p.toLowerCase().includes('kepala') || p.toUpperCase() === 'KETUA_ROMO') p = 'Kepala Romo Paroki';
        else if (p.toUpperCase() === 'ROMO_BIASA' || !p) p = 'Romo Paroki';
      }

      if (!p) {
        if (r === 'PENGURUS_LINGKUNGAN') return '<span class="inline-flex items-center px-2.5 py-1 rounded-lg bg-blue-50 text-blue-900 border border-blue-200 font-bold text-xs"><span>Pengurus Lingkungan</span></span>';
        if (r === 'ROMO_PAROKI') return '<span class="inline-flex items-center px-2.5 py-1 rounded-lg bg-blue-50 text-blue-900 border border-blue-200 font-bold text-xs"><span>Romo Paroki</span></span>';
        if (r === 'ROMO_ORDO') return '<span class="inline-flex items-center px-2.5 py-1 rounded-lg bg-blue-50 text-blue-900 border border-blue-200 font-bold text-xs"><span>Romo Ordo</span></span>';
        return '<span class="inline-flex items-center px-2.5 py-1 rounded-lg bg-slate-100 text-slate-700 border border-slate-200 font-bold text-xs"><span>-</span></span>';
      }

      return `<span class="inline-flex items-center px-2.5 py-1 rounded-lg bg-blue-50 text-blue-900 border border-blue-200 font-bold text-xs"><span>${p}</span></span>`;
    }

    // ══════════════════════════════════════════════════════════════════════════
    // 6. API ACTIONS, CASCADING DROPDOWNS & MASTER DATA CRUD
    // ══════════════════════════════════════════════════════════════════════════
