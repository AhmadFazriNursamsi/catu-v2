// ── Custom Searchable Combobox Component ──
    function renderCustomCombobox({
      id,
      name,
      label,
      badgeText,
      placeholder = '-- Pilih --',
      searchPlaceholder = 'Ketik untuk mencari...',
      options = [],
      selectedValue = '',
      onSelectCallback = '',
      onClearCallback = '',
      disabled = false,
      icon = ''
    }) {
      const isOpen = state.openCombobox === name;
      const searchVal = (state.comboboxFilters && state.comboboxFilters[name]) ? state.comboboxFilters[name].toLowerCase().trim() : '';
      
      const selectedItem = options.find(o => String(o.id) === String(selectedValue));
      const filteredOptions = options.filter(o => {
        if (!searchVal) return true;
        const nameMatch = o.name && o.name.toLowerCase().includes(searchVal);
        const codeMatch = o.code && o.code.toLowerCase().includes(searchVal);
        const extraMatch = o.extra && o.extra.toLowerCase().includes(searchVal);
        return nameMatch || codeMatch || extraMatch;
      });

      const activeBorder = isOpen ? 'ring-2 ring-amber-500 border-amber-500' : 'border-slate-200 hover:border-slate-300';

      return `
        <div class="custom-combobox-container relative">
          ${label ? `
            <div class="flex items-center justify-between mb-1.5">
              <label class="block font-bold text-slate-700 text-[11px] flex items-center">
                ${icon ? `<i data-lucide="${icon}" class="w-3.5 h-3.5 mr-1.5 text-slate-400"></i>` : ''}
                <span>${label}</span>
              </label>
              ${badgeText ? `<span class="text-[10px] text-slate-400 font-bold">${badgeText}</span>` : ''}
            </div>
          ` : ''}

          <!-- Hidden Input for Form Submission & ID querying -->
          <input type="hidden" id="${id}" value="${selectedValue || ''}" />

          <!-- Combobox Trigger Box -->
          <div class="relative">
            <button type="button" 
              onclick="${disabled ? '' : `toggleCustomCombobox('${name}')`}"
              ${disabled ? 'disabled' : ''}
              class="w-full px-3.5 py-2.5 bg-white border ${activeBorder} rounded-xl font-bold text-xs text-left flex items-center justify-between shadow-2xs transition ${disabled ? 'opacity-60 bg-slate-100 cursor-not-allowed text-slate-400' : 'text-slate-900 cursor-pointer'}">
              <span class="truncate ${selectedItem ? 'text-slate-900 font-bold' : 'text-slate-400 font-normal'}">
                ${selectedItem ? (selectedItem.name + (selectedItem.code ? ` (${selectedItem.code})` : '')) : placeholder}
              </span>
              <div class="flex items-center space-x-1.5 flex-shrink-0 ml-2">
                ${selectedItem && onClearCallback && !disabled ? `
                  <span onclick="event.stopPropagation(); ${onClearCallback}();" 
                    title="Hapus Pilihan"
                    class="p-0.5 rounded-full hover:bg-slate-200 text-slate-400 hover:text-slate-700 transition">
                    <i data-lucide="x" class="w-3.5 h-3.5"></i>
                  </span>
                ` : ''}
                <i data-lucide="chevron-down" class="w-4 h-4 text-slate-400 transition transform ${isOpen ? 'rotate-180 text-amber-600' : ''}"></i>
              </div>
            </button>
          </div>

          <!-- Dropdown Panel (Contains Search INSIDE & Scrollable Options) -->
          ${isOpen && !disabled ? `
            <div class="absolute left-0 right-0 top-full mt-1.5 z-50 bg-white border border-slate-200 rounded-2xl shadow-xl p-2.5 space-y-2 animate-fade-in custom-scrollbar">
              <!-- Search Input INSIDE the combobox dropdown -->
              <div class="relative">
                <i data-lucide="search" class="w-3.5 h-3.5 absolute left-3 top-1/2 -translate-y-1/2 text-slate-400"></i>
                <input type="text" id="comboboxSearch_${name}" placeholder="${searchPlaceholder}"
                  value="${state.comboboxFilters?.[name] || ''}"
                  oninput="onComboboxInnerSearch('${name}', this.value)"
                  class="w-full pl-8 pr-3 py-1.5 bg-slate-50 border border-slate-200 rounded-xl text-xs font-semibold text-slate-900 focus:outline-none focus:bg-white focus:ring-2 focus:ring-amber-500 shadow-2xs" />
              </div>

              <!-- Options List Inside Combobox -->
              <div class="max-h-48 overflow-y-auto space-y-0.5 custom-scrollbar">
                ${filteredOptions.map(opt => {
                  const isSelected = String(selectedValue) === String(opt.id);
                  return `
                    <button type="button" 
                      onclick="${onSelectCallback}('${opt.id}')"
                      class="w-full text-left px-3 py-2 rounded-xl text-xs transition flex items-center justify-between ${isSelected ? 'bg-amber-50 text-amber-950 font-black' : 'text-slate-700 font-semibold hover:bg-slate-100 hover:text-slate-900'}">
                      <div class="truncate">
                        <span>${opt.name}</span>
                        ${opt.subtext ? `<span class="text-[10px] text-slate-400 block">${opt.subtext}</span>` : ''}
                      </div>
                      ${isSelected ? `<i data-lucide="check" class="w-3.5 h-3.5 text-amber-600 flex-shrink-0 ml-1.5"></i>` : ''}
                    </button>
                  `;
                }).join('')}

                ${filteredOptions.length === 0 ? `
                  <div class="p-3 text-center text-xs text-slate-400 font-medium">
                    Tidak ada hasil ditemukan
                  </div>
                ` : ''}
              </div>
            </div>
          ` : ''}
        </div>
      `;
    }

    // ══════════════════════════════════════════════════════════════════════════
    // 5. COMPREHENSIVE EDIT USER PROFILE MODAL (WITH IN-COMBOBOX SEARCH)
    // ══════════════════════════════════════════════════════════════════════════

    function syncEditFormToState() {
      if (!state.activeEditUser) return;
      const u = state.activeEditUser;
      const fn = document.getElementById('editFullName');
      if (fn) u.full_name = fn.value;
      const em = document.getElementById('editEmail');
      if (em) u.email = em.value;
      const ph = document.getElementById('editPhone');
      if (ph) u.phone_number = ph.value;
      const bd = document.getElementById('editBirthDate');
      if (bd) u.birth_date = bd.value;
      const ad = document.getElementById('editAddress');
      if (ad) u.address = ad.value;
      const rc = document.getElementById('editRoleCode');
      if (rc) u.role_code = rc.value;
      const as = document.getElementById('editAccountStatus');
      if (as) u.account_status = as.value;
      const pr = document.getElementById('editProvinsiId');
      if (pr) u.provinsi_id = pr.value ? parseInt(pr.value) : null;
      const kk = document.getElementById('editKabupatenKotaId');
      if (kk) u.kabupaten_kota_id = kk.value ? parseInt(kk.value) : null;
      const ke = document.getElementById('editKeuskupanId');
      if (ke) u.keuskupan_id = ke.value ? parseInt(ke.value) : null;
      const pa = document.getElementById('editParokiId');
      if (pa) u.paroki_id = pa.value ? parseInt(pa.value) : null;
      const wi = document.getElementById('editWilayahId');
      if (wi) u.wilayah_id = wi.value ? parseInt(wi.value) : null;
      const li = document.getElementById('editLingkunganId');
      if (li) u.lingkungan_id = li.value ? parseInt(li.value) : null;
      const ord = document.getElementById('editOrdoId');
      if (ord) u.ordo_id = ord.value ? parseInt(ord.value) : null;
      const pp = document.getElementById('editPengurusPosition');
      if (pp) u.pengurus_position = pp.value;
      const rp = document.getElementById('editRomoPosition');
      if (rp) u.romo_position = rp.value;
      const rop = document.getElementById('editRomoOrdoPosition');
      if (rop) u.romo_position = rop.value;
      const sy = document.getElementById('editJabatanStartYear');
      if (sy) u.jabatan_start_year = sy.value ? parseInt(sy.value) : null;
      const ey = document.getElementById('editJabatanEndYear');
      if (ey) u.jabatan_end_year = ey.value ? parseInt(ey.value) : null;
    }

    function toggleCustomCombobox(name) {
      if (state.activeEditUser) syncEditFormToState();
      if (state.openCombobox === name) {
        state.openCombobox = null;
      } else {
        state.openCombobox = name;
        if (!state.comboboxFilters) state.comboboxFilters = {};
        state.comboboxFilters[name] = '';
        setTimeout(() => {
          const input = document.getElementById(`comboboxSearch_${name}`);
          if (input) input.focus();
        }, 60);
      }
      renderApp();
    }

    function onComboboxInnerSearch(name, query) {
      if (state.activeEditUser) syncEditFormToState();
      if (!state.comboboxFilters) state.comboboxFilters = {};
      state.comboboxFilters[name] = query;
      renderApp();
    }

    // ── Profile Edit Combobox Select & Clear Handlers ──

    function onComboboxSearchInput(field, value) {
      if (state.activeEditUser) {
        syncEditFormToState();
      }
      if (!state.comboboxFilters) state.comboboxFilters = {};
      state.comboboxFilters[field] = value;
      renderApp();
    }

    // Global Click Listener to close combobox dropdowns on outside click
    window.addEventListener('click', (e) => {
      if (state.openCombobox && !e.target.closest('.custom-combobox-container')) {
        state.openCombobox = null;
        if (typeof renderApp === 'function') renderApp();
      }
    });

