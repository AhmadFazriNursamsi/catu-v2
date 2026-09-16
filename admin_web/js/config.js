// ── Global Config, State & Utility Badges ──
    // Config & State
    const API_BASE = window.location.pathname.startsWith('/catuv2-admin')
      ? `${window.location.origin}/catuv2-api`
      : (window.location.hostname === 'apps.catu.id'
          ? 'https://apps.catu.id/catuv2-api'
          : `http://${window.location.hostname || 'localhost'}:3005`);
    let rawStoredUser = null;
    try {
      rawStoredUser = JSON.parse(localStorage.getItem('catu_admin_user') || 'null');
    } catch(e) { rawStoredUser = null; }

    // Load persisted Agentation annotations
    let rawStoredAnnotations = [];
    try {
      rawStoredAnnotations = JSON.parse(localStorage.getItem('catu_agentation_annotations') || '[]');
    } catch(e) { rawStoredAnnotations = []; }

    const state = {
      currentUser: (rawStoredUser && (rawStoredUser.roleCode === 'ADMIN' || rawStoredUser.role_code === 'ADMIN')) ? rawStoredUser : null,
      token: localStorage.getItem('catu_admin_token') || '',
      currentTab: 'overview',
      isSidebarOpen: localStorage.getItem('catu_sidebar_open') !== 'false',
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
        annotations: rawStoredAnnotations,
        pendingPin: null,
        activePinId: null,
        selectedCategory: 'BUG',
      }
    };

    function showToast(message, type = 'success', title = '', duration = 4000) {
      const id = 'toast_' + Date.now() + '_' + Math.random().toString(36).substr(2, 5);
      const defaultTitles = {
        success: 'Aksi Berhasil! ✨',
        error: 'Terjadi Kesalahan!',
        warning: 'Pemberitahuan Penting',
        info: 'Informasi Sistem'
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
      const idx = state.toasts.findIndex(t => t.id === id);
      if (idx !== -1) {
        state.toasts.splice(idx, 1);
        renderApp();
      }
    }

    function renderToastsContainer() {
      if (!state.toasts || state.toasts.length === 0) return '';

      return `
        <div class="fixed top-6 right-6 z-[99999] flex flex-col space-y-3 pointer-events-none max-w-sm w-full animate-fade-in">
          ${state.toasts.map(toast => {
            const isSuccess = toast.type === 'success';
            const isError = toast.type === 'error';
            const isWarning = toast.type === 'warning';
            
            const borderBg = isSuccess ? 'border-emerald-200/90 bg-gradient-to-r from-emerald-50/95 via-white to-white' :
              isError ? 'border-rose-200/90 bg-gradient-to-r from-rose-50/95 via-white to-white' :
              isWarning ? 'border-amber-200/90 bg-gradient-to-r from-amber-50/95 via-white to-white' :
              'border-blue-200/90 bg-gradient-to-r from-blue-50/95 via-white to-white';

            const iconBg = isSuccess ? 'bg-gradient-to-br from-emerald-500 to-emerald-600 text-white shadow-md shadow-emerald-500/30' :
              isError ? 'bg-gradient-to-br from-rose-500 to-rose-600 text-white shadow-md shadow-rose-500/30' :
              isWarning ? 'bg-gradient-to-br from-amber-500 to-amber-600 text-white shadow-md shadow-amber-500/30' :
              'bg-gradient-to-br from-blue-600 to-blue-700 text-white shadow-md shadow-blue-500/30';

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
        return 'bg-purple-50 text-purple-800 border border-purple-200';
      }
      if (s === 'FAIL' || s === 'REJECTED' || s === 'CANCELLED' || s === 'TIDAK AKTIF') {
        return 'bg-rose-50 text-rose-800 border border-rose-200';
      }
      return 'bg-amber-50 text-amber-800 border border-amber-200';
    }

    function getUserPositionBadge(pos, roleCode) {
      const p = (pos || '').trim();
      const r = (roleCode || '').toUpperCase();

      if (!p) {
        if (r === 'PENGURUS_LINGKUNGAN') return '<span class="inline-flex items-center px-3 py-1.5 rounded-xl bg-indigo-50 text-indigo-900 border border-indigo-200 font-bold text-xs shadow-2xs"><span>Pengurus Lingkungan</span></span>';
        if (r === 'ROMO_PAROKI') return '<span class="inline-flex items-center px-3 py-1.5 rounded-xl bg-emerald-50 text-emerald-900 border border-emerald-200 font-bold text-xs shadow-2xs"><span>Romo Paroki</span></span>';
        if (r === 'ROMO_ORDO') return '<span class="inline-flex items-center px-3 py-1.5 rounded-xl bg-purple-50 text-purple-900 border border-purple-200 font-bold text-xs shadow-2xs"><span>Romo Ordo</span></span>';
        return '<span class="inline-flex items-center px-3 py-1.5 rounded-xl bg-slate-100 text-slate-800 border border-slate-200 font-bold text-xs shadow-2xs"><span>-</span></span>';
      }

      const pLower = p.toLowerCase();
      // Pimpinan / Ketua / Kepala / Provinsial -> Amber
      if (pLower.includes('ketua') || pLower.includes('kepala') || pLower.includes('pimpinan') || pLower.includes('provinsial')) {
        return `<span class="inline-flex items-center px-3 py-1.5 rounded-xl bg-amber-50 text-amber-950 border border-amber-200 font-bold text-xs shadow-2xs"><span>${p}</span></span>`;
      }
      // Wakil / Sekretaris -> Indigo
      if (pLower.includes('wakil') || pLower.includes('sekretaris')) {
        return `<span class="inline-flex items-center px-3 py-1.5 rounded-xl bg-indigo-50 text-indigo-900 border border-indigo-200 font-bold text-xs shadow-2xs"><span>${p}</span></span>`;
      }
      // Bendahara -> Teal
      if (pLower.includes('bendahara')) {
        return `<span class="inline-flex items-center px-3 py-1.5 rounded-xl bg-teal-50 text-teal-900 border border-teal-200 font-bold text-xs shadow-2xs"><span>${p}</span></span>`;
      }
      // Romo Paroki -> Emerald
      if (r === 'ROMO_PAROKI' || pLower.includes('paroki')) {
        return `<span class="inline-flex items-center px-3 py-1.5 rounded-xl bg-emerald-50 text-emerald-900 border border-emerald-200 font-bold text-xs shadow-2xs"><span>${p}</span></span>`;
      }
      // Romo Ordo -> Purple
      if (r === 'ROMO_ORDO' || pLower.includes('ordo')) {
        return `<span class="inline-flex items-center px-3 py-1.5 rounded-xl bg-purple-50 text-purple-900 border border-purple-200 font-bold text-xs shadow-2xs"><span>${p}</span></span>`;
      }
      // Default / General Pengurus -> Blue
      return `<span class="inline-flex items-center px-3 py-1.5 rounded-xl bg-blue-50 text-blue-900 border border-blue-200 font-bold text-xs shadow-2xs"><span>${p}</span></span>`;
    }

    // ══════════════════════════════════════════════════════════════════════════
    // 6. API ACTIONS, CASCADING DROPDOWNS & MASTER DATA CRUD
    // ══════════════════════════════════════════════════════════════════════════
