// ── Master Data Create/Edit & Delete Modals ──
    function renderMasterModal() {
      const modal = state.activeMasterModal;
      if (!modal) return '';
      const { type, mode, data } = modal;
      const isEdit = mode === 'EDIT';

      const getTitle = () => {
        const prefix = isEdit ? 'Perbarui Data' : 'Tambah Baru';
        if (type === 'keuskupan') return `${prefix} Keuskupan`;
        if (type === 'paroki') return `${prefix} Paroki`;
        if (type === 'wilayah') return `${prefix} Wilayah`;
        if (type === 'lingkungan') return `${prefix} Lingkungan`;
        if (type === 'ordo') return `${prefix} Ordo / Kongregasi`;
        if (type === 'services') return `${prefix} Kategori Pelayanan`;
        return `${prefix} Master`;
      };

      return `
        <div class="fixed inset-0 z-50 bg-slate-900/40 backdrop-blur-xs flex items-center justify-center p-4 overflow-y-auto animate-fade-in">
          <div class="bg-white rounded-2xl max-w-lg w-full max-h-[90vh] overflow-y-auto shadow-xl border border-slate-200 custom-scrollbar my-8 overflow-hidden">
            <!-- Header -->
            <div class="p-6 border-b border-slate-100 flex items-start justify-between gap-4">
              <div class="flex items-center space-x-3.5 min-w-0">
                <div class="w-11 h-11 rounded-xl bg-slate-100 border border-slate-200 text-slate-700 flex items-center justify-center flex-shrink-0">
                  <i data-lucide="${isEdit ? 'edit-3' : 'plus'}" class="w-5 h-5 text-slate-600"></i>
                </div>
                <div class="min-w-0">
                  <h3 class="text-base font-bold text-slate-900 tracking-tight">${getTitle()}</h3>
                  <p class="text-xs text-slate-500 font-medium">
                    ${isEdit ? `Mengubah data ID #${data.id}` : 'Menyimpan entitas baru ke database'}
                  </p>
                </div>
              </div>
              <button onclick="state.activeMasterModal = null; renderApp();" 
                class="p-1.5 text-slate-400 hover:text-slate-700 hover:bg-slate-100 rounded-lg transition"
                title="Tutup">
                <i data-lucide="x" class="w-5 h-5"></i>
              </button>
            </div>

            <!-- Form Body -->
            <div class="p-6 space-y-4 text-xs">
              ${state.masterModalError ? `
                <div class="p-3.5 rounded-xl bg-rose-50 border border-rose-200 text-rose-800 text-xs font-bold flex items-start space-x-2 shadow-xs">
                  <i data-lucide="alert-circle" class="w-4 h-4 flex-shrink-0 text-rose-600 mt-0.5"></i>
                  <span>${state.masterModalError}</span>
                </div>
              ` : ''}

              <form id="masterForm" onsubmit="handleSaveMaster(event)" class="space-y-4">
                ${renderMasterModalFields(type, data)}

                <div class="pt-4 border-t border-slate-200 flex items-center justify-end space-x-2.5">
                  <button type="button" onclick="state.activeMasterModal = null; renderApp();"
                    class="px-4 py-2.5 rounded-xl bg-slate-100 hover:bg-slate-200 text-slate-700 font-bold text-xs transition">
                    Batal
                  </button>
                  <button type="submit" ${state.isSavingMaster ? 'disabled' : ''}
                    class="px-5 py-2.5 rounded-xl bg-blue-900 hover:bg-blue-950 text-white font-bold text-xs flex items-center space-x-2 shadow-sm transition disabled:opacity-50">
                    ${state.isSavingMaster ? `
                      <span class="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin"></span>
                      <span>Menyimpan...</span>
                    ` : `
                      <i data-lucide="save" class="w-4 h-4"></i>
                      <span>${isEdit ? 'Simpan Perubahan' : 'Tambah Sekarang'}</span>
                    `}
                  </button>
                </div>
              </form>
            </div>
          </div>
        </div>
      `;
    }

    function renderMasterModalFields(type, data) {
      if (type === 'keuskupan') {
        return `
          <div>
            <label class="block font-extrabold text-slate-700 mb-1.5">Nama Keuskupan *</label>
            <input type="text" id="masterNameInput" required value="${data.name || ''}" placeholder="misal: Keuskupan Agung Jakarta"
              class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl font-bold text-slate-900 focus:outline-none focus:ring-2 focus:ring-blue-500 shadow-xs" />
          </div>
        `;
      } else if (type === 'paroki') {
        return `
          ${renderCustomCombobox({
            id: 'masterKeuskupanIdInput',
            name: 'modalParokiKeuskupan',
            label: 'Keuskupan Induk *',
            icon: 'landmark',
            badgeText: `${(state.keuskupan || []).length} Keuskupan`,
            placeholder: '-- Pilih Keuskupan Induk --',
            searchPlaceholder: 'Cari Keuskupan...',
            options: (state.keuskupan || []).map(k => ({ id: k.id, name: k.name })),
            selectedValue: data.keuskupan_id || data.keuskupanId,
            onSelectCallback: 'onMasterModalKeuskupanSelectedForParoki',
          })}
          <div>
            <label class="block font-bold text-slate-700 mb-1.5">Nama Paroki *</label>
            <input type="text" id="masterNameInput" required value="${data.name || ''}" placeholder="misal: Paroki Santa Maria Regina"
              class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl font-bold text-slate-900 focus:outline-none focus:ring-2 focus:ring-blue-500 shadow-xs" />
          </div>
        `;
      } else if (type === 'wilayah') {
        const modal = state.activeMasterModal || {};
        const parokiList = (state.modalParokiList && state.modalParokiList.length > 0) ? state.modalParokiList : (state.paroki || []);
        const selectedParokiId = data.paroki_id || data.parokiId;
        return `
          <!-- 1. Filter Keuskupan -->
          <div class="p-3 bg-slate-50 border border-slate-200 rounded-2xl space-y-1.5">
            ${renderCustomCombobox({
              id: 'modalWilayahFilterKeuskupanId',
              name: 'modalWilayahKeuskupan',
              label: '1. Filter Keuskupan (Opsional)',
              icon: 'landmark',
              badgeText: `${(state.keuskupan || []).length} Keuskupan`,
              placeholder: '-- Tampilkan Semua Paroki --',
              searchPlaceholder: 'Cari Keuskupan...',
              options: (state.keuskupan || []).map(k => ({ id: k.id, name: k.name })),
              selectedValue: modal.filterKeuskupanId || data.keuskupan_id,
              onSelectCallback: 'onMasterModalKeuskupanSelectedForWilayah',
              onClearCallback: 'onMasterModalKeuskupanClearedForWilayah',
            })}
          </div>

          <!-- 2. Pilih Paroki Induk -->
          ${renderCustomCombobox({
            id: 'masterParokiIdInput',
            name: 'modalWilayahParoki',
            label: '2. Pilih Paroki Induk *',
            icon: 'church',
            badgeText: `${parokiList.length} Paroki Tersedia`,
            placeholder: '-- Pilih Paroki Induk --',
            searchPlaceholder: 'Cari Paroki Induk...',
            options: parokiList.map(p => ({ id: p.id, name: `${p.name} (${p.keuskupan_name || 'Keuskupan'})` })),
            selectedValue: selectedParokiId,
            onSelectCallback: 'onMasterModalParokiSelectedForWilayah',
          })}

          <!-- 3. Nama Wilayah -->
          <div>
            <label class="block font-bold text-slate-800 mb-1.5">3. Nama Wilayah Baru *</label>
            <input type="text" id="masterNameInput" required value="${data.name || ''}" placeholder="misal: Wilayah St. Fransiskus Xaverius"
              class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl font-bold text-slate-900 focus:outline-none focus:ring-2 focus:ring-amber-500 shadow-xs" />
          </div>
        `;
      } else if (type === 'lingkungan') {
        const modal = state.activeMasterModal || {};
        const parokiList = (state.modalParokiList && state.modalParokiList.length > 0) ? state.modalParokiList : (state.paroki || []);
        const wilayahList = (state.modalWilayahList && state.modalWilayahList.length > 0) ? state.modalWilayahList : (state.wilayah || []);
        const selectedWilayahId = data.wilayah_id || data.wilayahId;
        return `
          <!-- 1. Filter Keuskupan -->
          <div class="p-3 bg-slate-50 border border-slate-200 rounded-2xl space-y-1.5">
            ${renderCustomCombobox({
              id: 'modalLingkunganFilterKeuskupanId',
              name: 'modalLingkunganKeuskupan',
              label: '1. Filter Keuskupan (Opsional)',
              icon: 'landmark',
              badgeText: `${(state.keuskupan || []).length} Keuskupan`,
              placeholder: '-- Semua Keuskupan --',
              searchPlaceholder: 'Cari Keuskupan...',
              options: (state.keuskupan || []).map(k => ({ id: k.id, name: k.name })),
              selectedValue: modal.filterKeuskupanId || data.keuskupan_id,
              onSelectCallback: 'onMasterModalKeuskupanSelectedForLingkungan',
              onClearCallback: 'onMasterModalKeuskupanClearedForLingkungan',
            })}
          </div>

          <!-- 2. Filter Paroki -->
          <div class="p-3 bg-slate-50 border border-slate-200 rounded-2xl space-y-1.5">
            ${renderCustomCombobox({
              id: 'modalLingkunganFilterParokiId',
              name: 'modalLingkunganParoki',
              label: '2. Filter Paroki (Pilih untuk menyaring Wilayah)',
              icon: 'church',
              badgeText: `${parokiList.length} Paroki`,
              placeholder: '-- Pilih Paroki Induk --',
              searchPlaceholder: 'Cari Paroki...',
              options: parokiList.map(p => ({ id: p.id, name: `${p.name} (${p.keuskupan_name || 'Keuskupan'})` })),
              selectedValue: modal.filterParokiId || data.paroki_id,
              onSelectCallback: 'onMasterModalParokiSelectedForLingkungan',
              onClearCallback: 'onMasterModalParokiClearedForLingkungan',
            })}
          </div>

          <!-- 3. Pilih Wilayah Induk -->
          ${renderCustomCombobox({
            id: 'masterWilayahIdInput',
            name: 'modalLingkunganWilayah',
            label: '3. Pilih Wilayah Induk *',
            icon: 'map-pin',
            badgeText: `${wilayahList.length} Wilayah Tersedia`,
            placeholder: wilayahList.length === 0 ? '-- Pilih Paroki terlebih dahulu --' : '-- Pilih Wilayah Induk --',
            searchPlaceholder: 'Cari Wilayah...',
            options: wilayahList.map(w => ({ id: w.id, name: `${w.name} (${w.paroki_name || 'Paroki'})` })),
            selectedValue: selectedWilayahId,
            onSelectCallback: 'onMasterModalWilayahSelectedForLingkungan',
            disabled: wilayahList.length === 0
          })}

          <!-- 4. Nama Lingkungan -->
          <div>
            <label class="block font-bold text-slate-800 mb-1.5">4. Nama Lingkungan Baru *</label>
            <input type="text" id="masterNameInput" required value="${data.name || ''}" placeholder="misal: Lingkungan St. Gabriel 1"
              class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl font-bold text-slate-900 focus:outline-none focus:ring-2 focus:ring-amber-500 shadow-xs" />
          </div>
        `;
      } else if (type === 'ordo') {
        return `
          <div>
            <label class="block font-extrabold text-slate-700 mb-1.5">Nama Ordo / Kongregasi *</label>
            <input type="text" id="masterNameInput" required value="${data.name || ''}" placeholder="misal: Ordo Fratrum Minorum"
              class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl font-bold text-slate-900 focus:outline-none focus:ring-2 focus:ring-amber-500 shadow-xs" />
          </div>
          <div>
            <label class="block font-extrabold text-slate-700 mb-1.5">Kode Singkatan</label>
            <input type="text" id="masterCodeInput" value="${data.code || ''}" placeholder="misal: OFM, SJ, MSC, CSsR"
              class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl font-semibold text-slate-900 focus:outline-none focus:ring-2 focus:ring-amber-500 shadow-xs" />
          </div>
          <div>
            <label class="block font-extrabold text-slate-700 mb-1.5">Alamat Lengkap / Markas</label>
            <textarea id="masterAddressInput" rows="2" placeholder="misal: Jl. Kramat Raya No. 134, Jakarta Pusat"
              class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl font-semibold text-slate-900 focus:outline-none focus:ring-2 focus:ring-amber-500 shadow-xs">${data.address || ''}</textarea>
          </div>
        `;
      } else if (type === 'services') {
        return `
          <div>
            <label class="block font-extrabold text-slate-700 mb-1.5">Nama Sakramen / Pelayanan *</label>
            <input type="text" id="masterNameInput" required value="${data.name || ''}" placeholder="misal: Misa Syukur Ulang Tahun"
              class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl font-bold text-slate-900 focus:outline-none focus:ring-2 focus:ring-amber-500 shadow-xs" />
          </div>
          <div>
            <label class="block font-extrabold text-slate-700 mb-1.5">Deskripsi Pelayanan</label>
            <textarea id="masterDescInput" rows="2" placeholder="Deskripsi singkat mengenai pelayanan ini..."
              class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl font-semibold text-slate-900 focus:outline-none focus:ring-2 focus:ring-amber-500 shadow-xs">${data.description || ''}</textarea>
          </div>
          <div class="grid grid-cols-2 gap-3 pt-1">
            <label class="flex items-center space-x-2 p-3 bg-slate-50 rounded-xl border border-slate-200 cursor-pointer">
              <input type="checkbox" id="masterIsUrgentInput" ${data.is_urgent_by_default ? 'checked' : ''} class="w-4 h-4 rounded text-amber-500 focus:ring-amber-400" />
              <span class="font-bold text-slate-800">🚨 Default Urgent</span>
            </label>
            <label class="flex items-center space-x-2 p-3 bg-slate-50 rounded-xl border border-slate-200 cursor-pointer">
              <input type="checkbox" id="masterIsActiveInput" ${data.is_active !== false ? 'checked' : ''} class="w-4 h-4 rounded text-emerald-600 focus:ring-emerald-500" />
              <span class="font-bold text-slate-800">✓ Status Aktif</span>
            </label>
          </div>
        `;
      } else if (type === 'roles') {
        return `
          <div>
            <label class="block font-extrabold text-slate-700 mb-1.5">Kode Role (Singkatan Unik) *</label>
            <input type="text" id="masterCodeInput" required value="${data.code || ''}" placeholder="misal: PETUGAS_LITURGI, KOORDINATOR_WILAYAH"
              class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl font-mono font-bold text-slate-900 focus:outline-none focus:ring-2 focus:ring-amber-500 shadow-xs uppercase" />
            <p class="text-[10px] text-slate-400 mt-1">Gunakan huruf kapital dan garis bawah (misal: UMAT, ROMO_PAROKI, ADMIN)</p>
          </div>
          <div>
            <label class="block font-extrabold text-slate-700 mb-1.5">Nama Peran / Jenis Pengguna *</label>
            <input type="text" id="masterNameInput" required value="${data.name || ''}" placeholder="misal: Petugas Liturgi Gereja"
              class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl font-bold text-slate-900 focus:outline-none focus:ring-2 focus:ring-amber-500 shadow-xs" />
          </div>
        `;
      } else if (type === 'positions') {
        return `
          <div>
            <label class="block font-extrabold text-slate-700 mb-1.5">Kategori Struktur Jabatan *</label>
            <select id="masterCategoryInput" class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl font-bold text-slate-900 focus:outline-none focus:ring-2 focus:ring-amber-500 shadow-xs">
              <option value="PENGURUS_LINGKUNGAN" ${data.category === 'PENGURUS_LINGKUNGAN' ? 'selected' : ''}>Pengurus Lingkungan (Ketua, Wakil, Sekretaris)</option>
              <option value="ROMO_PAROKI" ${data.category === 'ROMO_PAROKI' ? 'selected' : ''}>Romo Paroki (Kepala Romo, Romo Paroki)</option>
              <option value="ROMO_ORDO" ${data.category === 'ROMO_ORDO' ? 'selected' : ''}>Romo Ordo (Ketua Romo Ordo, Romo Ordo)</option>
            </select>
          </div>
          <div>
            <label class="block font-extrabold text-slate-700 mb-1.5">Kode Jabatan (Singkatan Unik) *</label>
            <input type="text" id="masterCodeInput" required value="${data.code || ''}" placeholder="misal: KETUA_LINGKUNGAN, KEPALA_ROMO_PAROKI, SEKRETARIS"
              class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl font-mono font-bold text-slate-900 focus:outline-none focus:ring-2 focus:ring-amber-500 shadow-xs uppercase" />
          </div>
          <div>
            <label class="block font-extrabold text-slate-700 mb-1.5">Nama Jabatan Resmi *</label>
            <input type="text" id="masterNameInput" required value="${data.name || ''}" placeholder="misal: Ketua Lingkungan, Kepala Romo Paroki, Sekretaris"
              class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl font-bold text-slate-900 focus:outline-none focus:ring-2 focus:ring-amber-500 shadow-xs" />
          </div>
          <div class="pt-1">
            <label class="flex items-center space-x-2 p-3 bg-amber-50/70 rounded-xl border border-amber-200 cursor-pointer">
              <input type="checkbox" id="masterIsLeadInput" ${data.is_lead ? 'checked' : ''} class="w-4 h-4 rounded text-amber-600 focus:ring-amber-500" />
              <span class="font-extrabold text-amber-950 text-xs">Jabatan Pimpinan / Ketua Utama (Ketua / Kepala)</span>
            </label>
          </div>
        `;
      }
      return '';
    }

    // ── Delete Confirmation Modal ──
    function renderDeleteConfirmModal() {
      const del = state.deleteConfirmModal;
      if (!del) return '';

      return `
        <div class="fixed inset-0 z-50 bg-black/60 backdrop-blur-sm flex items-center justify-center p-4 animate-fade-in">
          <div class="bg-white rounded-2xl max-w-md w-full p-6 shadow-xl border border-slate-200 space-y-4">
            <div class="flex items-start space-x-3.5">
              <div class="w-12 h-12 rounded-2xl bg-rose-100 text-rose-600 flex items-center justify-center flex-shrink-0">
                <i data-lucide="alert-triangle" class="w-6 h-6"></i>
              </div>
              <div class="flex-1">
                <h3 class="text-base font-black text-slate-900">Konfirmasi Hapus Data</h3>
                <p class="text-xs text-slate-500 mt-1">
                  Apakah Anda yakin ingin menghapus <span class="font-bold text-slate-800">${del.name}</span> (#${del.id})? Tindakan ini tidak dapat dibatalkan.
                </p>
              </div>
            </div>

            ${del.errorMessage ? `
              <div class="p-3 rounded-xl bg-rose-50 border border-rose-200 text-rose-800 text-xs font-bold flex items-start space-x-2">
                <i data-lucide="alert-circle" class="w-4 h-4 flex-shrink-0 text-rose-600 mt-0.5"></i>
                <span>${del.errorMessage}</span>
              </div>
            ` : ''}

            <div class="pt-3 border-t border-slate-100 flex items-center justify-end space-x-2.5">
              <button onclick="state.deleteConfirmModal = null; renderApp();"
                class="px-4 py-2.5 rounded-xl bg-slate-100 hover:bg-slate-200 text-slate-700 font-extrabold text-xs transition">
                Batal
              </button>
              <button onclick="executeDeleteMaster()"
                class="px-5 py-2.5 rounded-xl bg-rose-600 hover:bg-rose-700 text-white font-extrabold text-xs shadow-md shadow-rose-600/20 transition">
                Ya, Hapus Permanen
              </button>
            </div>
          </div>
        </div>
      `;
    }

    // ── Toast Notifications System ──