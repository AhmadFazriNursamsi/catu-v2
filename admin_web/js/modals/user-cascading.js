// ── User Profile Cascading Location Selectors ──
    async function onEditProvinsiSelected(provId) {
      syncEditFormToState();
      state.openCombobox = null;
      state.activeEditUser.provinsi_id = provId ? parseInt(provId) : null;
      state.activeEditUser.kabupaten_kota_id = null;
      try {
        const url = provId ? `${API_BASE}/auth/kabupaten-kota?provinsiId=${provId}` : `${API_BASE}/auth/kabupaten-kota`;
        const res = await fetch(url);
        state.editKabupatenKotaList = await res.json();
      } catch (e) {
        state.editKabupatenKotaList = [];
      }
      renderApp();
    }

    function onEditProvinsiCleared() {
      onEditProvinsiSelected(null);
    }

    function onEditKabupatenKotaSelected(kkId) {
      syncEditFormToState();
      state.openCombobox = null;
      state.activeEditUser.kabupaten_kota_id = kkId ? parseInt(kkId) : null;
      renderApp();
    }

    function onEditKabupatenKotaCleared() {
      onEditKabupatenKotaSelected(null);
    }

    async function onEditKeuskupanSelected(keuskupanId) {
      syncEditFormToState();
      state.openCombobox = null;
      state.activeEditUser.keuskupan_id = keuskupanId ? parseInt(keuskupanId) : null;
      state.activeEditUser.paroki_id = null;
      state.activeEditUser.wilayah_id = null;
      state.activeEditUser.lingkungan_id = null;
      try {
        const url = keuskupanId ? `${API_BASE}/auth/paroki?keuskupanId=${keuskupanId}` : `${API_BASE}/auth/paroki`;
        const res = await fetch(url);
        state.editParokiList = await res.json();
        state.editWilayahList = [];
        state.editLingkunganList = [];
      } catch (e) {
        state.editParokiList = [];
        state.editWilayahList = [];
        state.editLingkunganList = [];
      }
      renderApp();
    }

    function onEditKeuskupanCleared() {
      onEditKeuskupanSelected(null);
    }

    async function onEditParokiSelected(parokiId) {
      syncEditFormToState();
      state.openCombobox = null;
      state.activeEditUser.paroki_id = parokiId ? parseInt(parokiId) : null;
      state.activeEditUser.wilayah_id = null;
      state.activeEditUser.lingkungan_id = null;
      try {
        if (parokiId) {
          const res = await fetch(`${API_BASE}/auth/wilayah?parokiId=${parokiId}`);
          state.editWilayahList = await res.json();
        } else {
          state.editWilayahList = [];
        }
        state.editLingkunganList = [];
      } catch (e) {
        state.editWilayahList = [];
        state.editLingkunganList = [];
      }
      renderApp();
    }

    function onEditParokiCleared() {
      onEditParokiSelected(null);
    }

    async function onEditWilayahSelected(wilayahId) {
      syncEditFormToState();
      state.openCombobox = null;
      state.activeEditUser.wilayah_id = wilayahId ? parseInt(wilayahId) : null;
      state.activeEditUser.lingkungan_id = null;
      try {
        if (wilayahId) {
          const res = await fetch(`${API_BASE}/auth/lingkungan?wilayahId=${wilayahId}`);
          state.editLingkunganList = await res.json();
        } else {
          state.editLingkunganList = [];
        }
      } catch (e) {
        state.editLingkunganList = [];
      }
      renderApp();
    }

    function onEditWilayahCleared() {
      onEditWilayahSelected(null);
    }

    function onEditLingkunganSelected(lingkunganId) {
      syncEditFormToState();
      state.openCombobox = null;
      state.activeEditUser.lingkungan_id = lingkunganId ? parseInt(lingkunganId) : null;
      renderApp();
    }

    function onEditLingkunganCleared() {
      onEditLingkunganSelected(null);
    }

    function onEditOrdoSelected(ordoId) {
      syncEditFormToState();
      state.openCombobox = null;
      state.activeEditUser.ordo_id = ordoId ? parseInt(ordoId) : null;
      renderApp();
    }

    function onEditOrdoCleared() {
      onEditOrdoSelected(null);
    }

    // ── Master Modal Combobox Handlers ──
