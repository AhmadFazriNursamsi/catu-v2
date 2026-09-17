// ── Master Data Modal Handlers ──
    async function onMasterModalKeuskupanChangedForWilayah(keuskupanId) {
      if (!state.activeMasterModal) return;
      state.activeMasterModal.filterKeuskupanId = keuskupanId;
      try {
        const url = keuskupanId ? `${API_BASE}/master/paroki?keuskupanId=${keuskupanId}` : `${API_BASE}/master/paroki`;
        const res = await fetch(url);
        state.modalParokiList = await res.json();
      } catch (e) {
        console.error(e);
      }
      renderApp();
    }

    async function onMasterModalKeuskupanChangedForLingkungan(keuskupanId) {
      if (!state.activeMasterModal) return;
      state.activeMasterModal.filterKeuskupanId = keuskupanId;
      state.activeMasterModal.filterParokiId = '';
      try {
        const url = keuskupanId ? `${API_BASE}/master/paroki?keuskupanId=${keuskupanId}` : `${API_BASE}/master/paroki`;
        const res = await fetch(url);
        state.modalParokiList = await res.json();
        state.modalWilayahList = [];
      } catch (e) {
        console.error(e);
      }
      renderApp();
    }

    async function onMasterModalParokiChangedForLingkungan(parokiId) {
      if (!state.activeMasterModal) return;
      state.activeMasterModal.filterParokiId = parokiId;
      try {
        const url = parokiId ? `${API_BASE}/master/wilayah?parokiId=${parokiId}` : `${API_BASE}/master/wilayah`;
        const res = await fetch(url);
        state.modalWilayahList = await res.json();
      } catch (e) {
        console.error(e);
      }
      renderApp();
    }

    async function openCreateMasterModal(type, prefillData = {}) {
      state.masterModalError = '';
      state.comboboxFilters = {};
      const activeType = type || state.masterSubTab || 'paroki';
      const initialData = { ...prefillData };

      // Pre-fill active table filter if available
      if (activeType === 'paroki' && state.masterFilterKeuskupanId && !initialData.keuskupan_id) {
        initialData.keuskupan_id = parseInt(state.masterFilterKeuskupanId);
      }
      if (activeType === 'wilayah' && state.masterFilterParokiId && !initialData.paroki_id) {
        initialData.paroki_id = parseInt(state.masterFilterParokiId);
      }

      let filterKId = initialData.keuskupan_id || '';
      let filterPId = initialData.paroki_id || '';

      try {
        if (activeType === 'paroki') {
          const res = await fetch(`${API_BASE}/master/keuskupan`);
          state.keuskupan = await res.json();
        } else if (activeType === 'wilayah') {
          const [kRes, pRes] = await Promise.all([
            fetch(`${API_BASE}/master/keuskupan`),
            fetch(`${API_BASE}/master/paroki${filterKId ? '?keuskupanId=' + filterKId : ''}`)
          ]);
          state.keuskupan = await kRes.json();
          state.modalParokiList = await pRes.json();
        } else if (activeType === 'lingkungan') {
          const [kRes, pRes, wRes] = await Promise.all([
            fetch(`${API_BASE}/master/keuskupan`),
            fetch(`${API_BASE}/master/paroki${filterKId ? '?keuskupanId=' + filterKId : ''}`),
            fetch(`${API_BASE}/master/wilayah${filterPId ? '?parokiId=' + filterPId : ''}`)
          ]);
          state.keuskupan = await kRes.json();
          state.modalParokiList = await pRes.json();
          state.modalWilayahList = await wRes.json();
        }
      } catch (err) {
        console.error('Error preloading lookup data for modal:', err);
      }

      state.activeMasterModal = {
        type: activeType,
        mode: 'CREATE',
        data: initialData,
        filterKeuskupanId: filterKId,
        filterParokiId: filterPId
      };
      renderApp();
    }

    async function openEditMasterModal(type, item) {
      state.masterModalError = '';
      state.comboboxFilters = {};
      const activeType = type || state.masterSubTab || 'paroki';
      const initialData = { ...item };

      let filterKId = initialData.keuskupan_id || '';
      let filterPId = initialData.paroki_id || '';

      try {
        if (activeType === 'paroki') {
          const res = await fetch(`${API_BASE}/master/keuskupan`);
          state.keuskupan = await res.json();
        } else if (activeType === 'wilayah') {
          const [kRes, pRes] = await Promise.all([
            fetch(`${API_BASE}/master/keuskupan`),
            fetch(`${API_BASE}/master/paroki`)
          ]);
          state.keuskupan = await kRes.json();
          state.modalParokiList = await pRes.json();
        } else if (activeType === 'lingkungan') {
          const [kRes, pRes, wRes] = await Promise.all([
            fetch(`${API_BASE}/master/keuskupan`),
            fetch(`${API_BASE}/master/paroki`),
            fetch(`${API_BASE}/master/wilayah`)
          ]);
          state.keuskupan = await kRes.json();
          state.modalParokiList = await pRes.json();
          state.modalWilayahList = await wRes.json();
        }
      } catch (err) {
        console.error('Error preloading lookup data for modal:', err);
      }

      state.activeMasterModal = {
        type: activeType,
        mode: 'EDIT',
        data: initialData,
        filterKeuskupanId: filterKId,
        filterParokiId: filterPId
      };
      renderApp();
    }

    async function handleSaveMaster(event) {
      if (event) event.preventDefault();
      const modal = state.activeMasterModal;
      if (!modal) return;

      const { type, mode, data } = modal;
      let endpoint = '';
      let method = mode === 'CREATE' ? 'POST' : 'PUT';
      let payload = {};

      try {
        // 1. Read DOM inputs FIRST before any renderApp call
        if (type === 'keuskupan') {
          endpoint = mode === 'CREATE' ? `${API_BASE}/master/keuskupan` : `${API_BASE}/master/keuskupan/${data.id}`;
          const nameVal = document.getElementById('masterNameInput')?.value?.trim();
          const codeVal = document.getElementById('masterCodeInput')?.value?.trim();
          if (!nameVal) throw new Error('Nama Keuskupan wajib diisi');
          payload = { name: nameVal };
          if (codeVal) payload.code = codeVal;
          modal.data.name = nameVal;
          modal.data.code = codeVal;
        } else if (type === 'paroki') {
          endpoint = mode === 'CREATE' ? `${API_BASE}/master/paroki` : `${API_BASE}/master/paroki/${data.id}`;
          const keuskupanIdVal = parseInt(document.getElementById('masterKeuskupanIdInput')?.value);
          const nameVal = document.getElementById('masterNameInput')?.value?.trim();
          const addressVal = document.getElementById('masterAddressInput')?.value?.trim();
          if (!keuskupanIdVal || isNaN(keuskupanIdVal)) throw new Error('Silakan pilih Keuskupan terlebih dahulu');
          if (!nameVal) throw new Error('Nama Paroki wajib diisi');
          payload = { keuskupanId: keuskupanIdVal, name: nameVal };
          if (addressVal) payload.address = addressVal;
          modal.data.keuskupan_id = keuskupanIdVal;
          modal.data.name = nameVal;
          modal.data.address = addressVal;
        } else if (type === 'wilayah') {
          endpoint = mode === 'CREATE' ? `${API_BASE}/master/wilayah` : `${API_BASE}/master/wilayah/${data.id}`;
          const parokiIdVal = parseInt(document.getElementById('masterParokiIdInput')?.value);
          const nameVal = document.getElementById('masterNameInput')?.value?.trim();
          if (!parokiIdVal || isNaN(parokiIdVal)) throw new Error('Silakan pilih Paroki terlebih dahulu');
          if (!nameVal) throw new Error('Nama Wilayah wajib diisi');
          payload = { parokiId: parokiIdVal, name: nameVal };
          modal.data.paroki_id = parokiIdVal;
          modal.data.name = nameVal;
        } else if (type === 'lingkungan') {
          endpoint = mode === 'CREATE' ? `${API_BASE}/master/lingkungan` : `${API_BASE}/master/lingkungan/${data.id}`;
          const wilayahIdVal = parseInt(document.getElementById('masterWilayahIdInput')?.value);
          const nameVal = document.getElementById('masterNameInput')?.value?.trim();
          if (!wilayahIdVal || isNaN(wilayahIdVal)) throw new Error('Silakan pilih Wilayah terlebih dahulu');
          if (!nameVal) throw new Error('Nama Lingkungan wajib diisi');
          payload = { wilayahId: wilayahIdVal, name: nameVal };
          modal.data.wilayah_id = wilayahIdVal;
          modal.data.name = nameVal;
        } else if (type === 'ordo') {
          endpoint = mode === 'CREATE' ? `${API_BASE}/master/ordo` : `${API_BASE}/master/ordo/${data.id}`;
          const nameVal = document.getElementById('masterNameInput')?.value?.trim();
          const codeVal = document.getElementById('masterCodeInput')?.value?.trim();
          const addressVal = document.getElementById('masterAddressInput')?.value?.trim();
          if (!nameVal) throw new Error('Nama Ordo / Kongregasi wajib diisi');
          payload = { name: nameVal };
          if (codeVal) payload.code = codeVal;
          if (addressVal) payload.address = addressVal;
          modal.data.name = nameVal;
          modal.data.code = codeVal;
          modal.data.address = addressVal;
        } else if (type === 'services') {
          endpoint = mode === 'CREATE' ? `${API_BASE}/master/service-categories` : `${API_BASE}/master/service-categories/${data.id}`;
          const nameVal = document.getElementById('masterNameInput')?.value?.trim();
          const descVal = document.getElementById('masterDescInput')?.value?.trim();
          const isUrgent = document.getElementById('masterIsUrgentInput')?.checked || false;
          const isActive = document.getElementById('masterIsActiveInput')?.checked !== false;
          if (!nameVal) throw new Error('Nama Sakramen / Pelayanan wajib diisi');
          payload = {
            name: nameVal,
            isUrgentByDefault: isUrgent,
            isActive: isActive
          };
          if (descVal) payload.description = descVal;
          modal.data.name = nameVal;
          modal.data.description = descVal;
          modal.data.is_urgent_by_default = isUrgent;
          modal.data.is_active = isActive;
        } else if (type === 'roles') {
          endpoint = mode === 'CREATE' ? `${API_BASE}/master/roles` : `${API_BASE}/master/roles/${data.id}`;
          const codeVal = document.getElementById('masterCodeInput')?.value?.trim().toUpperCase().replace(/\s+/g, '_');
          const nameVal = document.getElementById('masterNameInput')?.value?.trim();
          if (!codeVal) throw new Error('Kode Role wajib diisi');
          if (!nameVal) throw new Error('Nama Jenis Role wajib diisi');
          payload = { code: codeVal, name: nameVal };
          modal.data.code = codeVal;
          modal.data.name = nameVal;
        } else if (type === 'positions') {
          endpoint = mode === 'CREATE' ? `${API_BASE}/master/positions` : `${API_BASE}/master/positions/${data.id}`;
          const categoryVal = document.getElementById('masterCategoryInput')?.value;
          const codeVal = document.getElementById('masterCodeInput')?.value?.trim().toUpperCase().replace(/\s+/g, '_');
          const nameVal = document.getElementById('masterNameInput')?.value?.trim();
          const isLeadVal = document.getElementById('masterIsLeadInput')?.checked || false;
          if (!categoryVal) throw new Error('Kategori Struktur Jabatan wajib dipilih');
          if (!codeVal) throw new Error('Kode Jabatan wajib diisi');
          if (!nameVal) throw new Error('Nama Jabatan wajib diisi');
          payload = { category: categoryVal, code: codeVal, name: nameVal, isLead: isLeadVal };
          modal.data.category = categoryVal;
          modal.data.code = codeVal;
          modal.data.name = nameVal;
          modal.data.is_lead = isLeadVal;
        }

        // 2. Now set loading state and render spinner
        state.isSavingMaster = true;
        state.masterModalError = '';
        renderApp();

        // 3. Send request to backend
        const res = await fetch(endpoint, {
          method: method,
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(payload)
        });

        const result = await res.json();
        if (!res.ok) {
          const errMsg = Array.isArray(result.message) ? result.message.join(', ') : (result.message || 'Gagal menyimpan data.');
          throw new Error(errMsg);
        }

        state.activeMasterModal = null;

        const savedItem = result.data || result;
        if (savedItem && savedItem.id) {
          state.lastCreatedMasterId = savedItem.id;
        }

        try {
          const label = typeof getMasterEntityLabel === 'function' ? getMasterEntityLabel(type) : (type || 'Data');
          showToast(`Data ${label} "${modal.data.name || ''}" berhasil disimpan ke sistem!`, 'success', mode === 'CREATE' ? 'Data Berhasil Ditambahkan! 🎉' : 'Perubahan Berhasil Disimpan! ✨');
        } catch (_) {}

        // Align target subtab and reset search/filters so newly created data is immediately visible
        state.masterSubTab = type;
        state.masterSearch = '';
        if (mode === 'CREATE') {
          state.masterFilterKeuskupanId = '';
          state.masterFilterParokiId = '';
          state.masterFilterWilayahId = '';
        }

        // Authoritatively re-fetch fresh grid data and global lookups from database
        await loadMasterData(state.masterSubTab);
        await refreshMasterLookups();
        renderApp();
      } catch (err) {
        state.masterModalError = err.message || 'Terjadi kesalahan sistem.';
        renderApp();
      } finally {
        state.isSavingMaster = false;
        renderApp();
      }
    }
