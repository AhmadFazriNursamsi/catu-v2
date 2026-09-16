// ── Master Modal Cascading Selectors ──
    function onMasterModalKeuskupanSelectedForParoki(keuskupanId) {
      state.openCombobox = null;
      if (state.activeMasterModal) {
        state.activeMasterModal.data.keuskupan_id = keuskupanId;
      }
      const el = document.getElementById('masterKeuskupanIdInput');
      if (el) el.value = keuskupanId;
      renderApp();
    }

    async function onMasterModalKeuskupanSelectedForWilayah(keuskupanId) {
      state.openCombobox = null;
      await onMasterModalKeuskupanChangedForWilayah(keuskupanId);
    }

    async function onMasterModalKeuskupanClearedForWilayah() {
      state.openCombobox = null;
      await onMasterModalKeuskupanChangedForWilayah('');
    }

    function onMasterModalParokiSelectedForWilayah(parokiId) {
      state.openCombobox = null;
      if (state.activeMasterModal) {
        state.activeMasterModal.data.paroki_id = parokiId;
      }
      const el = document.getElementById('masterParokiIdInput');
      if (el) el.value = parokiId;
      renderApp();
    }

    async function onMasterModalKeuskupanSelectedForLingkungan(keuskupanId) {
      state.openCombobox = null;
      await onMasterModalKeuskupanChangedForLingkungan(keuskupanId);
    }

    async function onMasterModalKeuskupanClearedForLingkungan() {
      state.openCombobox = null;
      await onMasterModalKeuskupanChangedForLingkungan('');
    }

    async function onMasterModalParokiSelectedForLingkungan(parokiId) {
      state.openCombobox = null;
      await onMasterModalParokiChangedForLingkungan(parokiId);
    }

    async function onMasterModalParokiClearedForLingkungan() {
      state.openCombobox = null;
      await onMasterModalParokiChangedForLingkungan('');
    }

    function onMasterModalWilayahSelectedForLingkungan(wilayahId) {
      state.openCombobox = null;
      if (state.activeMasterModal) {
        state.activeMasterModal.data.wilayah_id = wilayahId;
      }
      const el = document.getElementById('masterWilayahIdInput');
      if (el) el.value = wilayahId;
      renderApp();
    }

    // Keep legacy fallback for any inline elements
