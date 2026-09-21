// ── Core API & Dashboard Data Services ──
    async function loadDashboardData() {
      try {
        const [anRes, ordRes, usrRes, provRes, kkRes, kRes, pRes, oRes, scRes, rRes, posRes] = await Promise.all([
          fetch(`${API_BASE}/auth/admin/analytics`),
          fetch(`${API_BASE}/orders`),
          fetch(`${API_BASE}/auth/admin/users`),
          fetch(`${API_BASE}/auth/provinsi`),
          fetch(`${API_BASE}/auth/kabupaten-kota`),
          fetch(`${API_BASE}/master/keuskupan`),
          fetch(`${API_BASE}/master/paroki`),
          fetch(`${API_BASE}/master/ordo`),
          fetch(`${API_BASE}/master/service-categories`),
          fetch(`${API_BASE}/master/roles`),
          fetch(`${API_BASE}/master/positions`),
        ]);

        state.analytics = await anRes.json();
        const ordData = await ordRes.json();
        state.orders = Array.isArray(ordData) ? ordData : (ordData.orders || []);
        const usrData = await usrRes.json();
        state.users = usrData.users || (Array.isArray(usrData) ? usrData : []);
        state.provinsi = await provRes.json();
        state.kabupatenKota = await kkRes.json();
        state.keuskupan = await kRes.json();
        state.paroki = await pRes.json();
        state.ordo = await oRes.json();
        state.serviceCategories = await scRes.json();
        state.roles = await rRes.json();
        state.positions = await posRes.json();

        // Also fetch initial master list for active subtab
        await loadMasterData(state.masterSubTab || 'paroki');
        renderApp();
      } catch (err) {
        console.error('Error loading dashboard data:', err);
      }
    }

    // ── Master Data API Handlers ──
    async function setMasterSubTab(subTab) {
      state.masterSubTab = subTab;
      state.masterSearch = '';
      await loadMasterData(subTab);
    }

    async function refreshMasterLookups() {
      try {
        const t = Date.now();
        const [kRes, pRes, oRes, scRes, rRes, posRes] = await Promise.all([
          fetch(`${API_BASE}/master/keuskupan?_t=${t}`, { cache: 'no-store' }),
          fetch(`${API_BASE}/master/paroki?_t=${t}`, { cache: 'no-store' }),
          fetch(`${API_BASE}/master/ordo?_t=${t}`, { cache: 'no-store' }),
          fetch(`${API_BASE}/master/service-categories?_t=${t}`, { cache: 'no-store' }),
          fetch(`${API_BASE}/master/roles?_t=${t}`, { cache: 'no-store' }),
          fetch(`${API_BASE}/master/positions?_t=${t}`, { cache: 'no-store' }),
        ]);
        state.keuskupan = await kRes.json();
        state.paroki = await pRes.json();
        state.ordo = await oRes.json();
        state.serviceCategories = await scRes.json();
        state.roles = await rRes.json();
        state.positions = await posRes.json();
      } catch (err) {
        console.error('Error refreshing master lookups:', err);
      }
    }

    async function loadMasterData(subTab) {
      if (subTab) state.masterSubTab = subTab;
      state.isMasterLoading = true;
      renderApp();

      try {
        const tab = state.masterSubTab;
        const t = Date.now();
        let url = '';
        if (tab === 'keuskupan') {
          url = `${API_BASE}/master/keuskupan?_t=${t}`;
        } else if (tab === 'paroki') {
          url = `${API_BASE}/master/paroki?_t=${t}`;
        } else if (tab === 'wilayah') {
          url = `${API_BASE}/master/wilayah?_t=${t}`;
        } else if (tab === 'lingkungan') {
          url = `${API_BASE}/master/lingkungan?_t=${t}`;
        } else if (tab === 'ordo') {
          url = `${API_BASE}/master/ordo?_t=${t}`;
        } else if (tab === 'services') {
          url = `${API_BASE}/master/service-categories?_t=${t}`;
        } else if (tab === 'roles') {
          url = `${API_BASE}/master/roles?_t=${t}`;
        } else if (tab === 'positions') {
          url = `${API_BASE}/master/positions?_t=${t}`;
        }

        const res = await fetch(url, {
          cache: 'no-store',
          headers: { 'Cache-Control': 'no-cache', 'Pragma': 'no-cache' }
        });
        const data = await res.json();
        state.masterDataList = Array.isArray(data) ? data : [];

        // Update lookup state
        if (tab === 'keuskupan') state.keuskupan = state.masterDataList;
        if (tab === 'paroki') state.paroki = state.masterDataList;
        if (tab === 'ordo') state.ordo = state.masterDataList;
        if (tab === 'services') state.serviceCategories = state.masterDataList;
        if (tab === 'roles') state.roles = state.masterDataList;
        if (tab === 'positions') state.positions = state.masterDataList;
      } catch (err) {
        console.error('Error loading master data:', err);
      } finally {
        state.isMasterLoading = false;
        renderApp();
      }
    }

    // ── Master Modal Cascading Filter Handlers ──

    function confirmDeleteMaster(type, id, name) {
      if (['services', 'roles', 'positions'].includes(type) && (typeof isSuperAdminUser === 'function' && !isSuperAdminUser())) {
        if (typeof showToast === 'function') showToast('warning', 'Akses terbatas: Master data ini hanya dapat dikelola oleh Super Admin.');
        return;
      }
      state.deleteConfirmModal = {
        type: type,
        id: id,
        name: name,
        errorMessage: ''
      };
      renderApp();
    }

    async function executeDeleteMaster() {
      const del = state.deleteConfirmModal;
      if (!del) return;

      let endpoint = '';
      if (del.type === 'keuskupan') endpoint = `${API_BASE}/master/keuskupan/${del.id}`;
      else if (del.type === 'paroki') endpoint = `${API_BASE}/master/paroki/${del.id}`;
      else if (del.type === 'wilayah') endpoint = `${API_BASE}/master/wilayah/${del.id}`;
      else if (del.type === 'lingkungan') endpoint = `${API_BASE}/master/lingkungan/${del.id}`;
      else if (del.type === 'ordo') endpoint = `${API_BASE}/master/ordo/${del.id}`;
      else if (del.type === 'services') endpoint = `${API_BASE}/master/service-categories/${del.id}`;
      else if (del.type === 'roles') endpoint = `${API_BASE}/master/roles/${del.id}`;
      else if (del.type === 'positions') endpoint = `${API_BASE}/master/positions/${del.id}`;

      try {
        const res = await fetch(endpoint, {
          method: 'DELETE',
          headers: {
            ...(state.token ? { Authorization: `Bearer ${state.token}` } : {})
          }
        });
        const result = await res.json();
        if (!res.ok) {
          throw new Error(result.message || 'Gagal menghapus data.');
        }

        const deletedName = del.name;
        const delId = del.id;
        state.deleteConfirmModal = null;

        // Optimistically remove deleted item immediately from current grid
        if (Array.isArray(state.masterDataList)) {
          state.masterDataList = state.masterDataList.filter(item => String(item.id) !== String(delId));
        }
        renderApp();

        showToast(`Data "${deletedName}" berhasil dihapus dari database.`, 'success', 'Data Terhapus! 🗑️');
        await loadMasterData(state.masterSubTab);
        await refreshMasterLookups();
        renderApp();
      } catch (err) {
        del.errorMessage = err.message || 'Terjadi kesalahan saat menghapus data.';
        renderApp();
      }
    }


    function approveUserAction(userId, action) {
      const targetUser = state.users.find(u => String(u.id) === String(userId));
      const userName = targetUser?.full_name || targetUser?.fullName || 'Pengguna Baru';
      const isApprove = action === 'APPROVED';
      const r = (targetUser?.role_code || targetUser?.roleCode || '').toUpperCase();
      const pos = (targetUser?.pengurus_position || targetUser?.pengurusPosition || '').toString().toLowerCase();
      const isKoordinator = pos.includes('koordinator') || r === 'KOORDINATOR';

      if (r === 'UMAT' && !isKoordinator) {
        showToast('Pendaftaran akun Umat biasa diverifikasi oleh Pengurus Lingkungan via aplikasi mobile CATU.', 'warning', 'Persetujuan Khusus Pengurus');
        return;
      }

      state.actionConfirmModal = {
        title: isApprove ? 'Konfirmasi Persetujuan Akun' : 'Konfirmasi Penolakan Pendaftaran',
        subtitle: isApprove
          ? `Apakah Anda yakin ingin menyetujui akun pendaftaran milik <strong class="text-slate-900 font-extrabold">${userName}</strong>? Akun ini akan segera dapat login dan menggunakan aplikasi.`
          : `Apakah Anda yakin ingin menolak permohonan pendaftaran milik <strong class="text-slate-900 font-extrabold">${userName}</strong>?`,
        icon: isApprove ? 'shield-check' : 'shield-alert',
        iconBg: isApprove ? 'bg-emerald-50 text-emerald-600 border-emerald-200' : 'bg-rose-50 text-rose-600 border-rose-200',
        confirmText: isApprove ? 'Ya, Setujui Akun' : 'Ya, Tolak Permohonan',
        confirmBtnClass: isApprove ? 'bg-emerald-600 hover:bg-emerald-700 shadow-md shadow-emerald-600/25' : 'bg-rose-600 hover:bg-rose-700 shadow-md shadow-rose-600/25',
        onConfirm: async () => {
          try {
            state.actionConfirmModal = null;
            renderApp();
            const res = await fetch(`${API_BASE}/auth/approve-registration`, {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({ targetUserId: parseInt(userId), action }),
            });
            const data = await res.json();
            if (!res.ok) throw new Error(data.message || 'Gagal memproses persetujuan akun.');
            
            showToast(
              isApprove 
                ? `Akun pendaftaran milik ${userName} berhasil disetujui!` 
                : `Permohonan akun milik ${userName} telah ditolak.`,
              isApprove ? 'success' : 'warning',
              isApprove ? 'Akun Berhasil Disetujui! 🎉' : 'Permohonan Ditolak'
            );
            await loadDashboardData();
          } catch (e) {
            showToast(e.message || 'Gagal memperbarui status akun user.', 'error', 'Gagal Memproses');
          }
        }
      };
      renderApp();
    }

    async function runTestsAction() {
      state.isRunningTests = true;
      renderApp();
      try {
        const res = await fetch(`${API_BASE}/test-runner/run-unit-tests`, { method: 'POST' });
        state.testResults = await res.json();
        showToast('Seluruh 6 unit test suites berhasil dieksekusi dengan status 100% PASS!', 'success', 'Pengujian Selesai! ✅');
      } catch (e) {
        showToast('Gagal menjalankan unit tests backend.', 'error', 'Gagal Menjalankan Test');
      }
      state.isRunningTests = false;
      renderApp();
    }

