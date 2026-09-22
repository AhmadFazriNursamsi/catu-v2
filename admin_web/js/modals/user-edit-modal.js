// ── User Edit Form Modal ──
    function renderEditUserModal() {
      const u = state.activeEditUser;
      if (!u) return '';
      const roleCode = (u.role_code || u.roleCode || 'UMAT').toUpperCase();
      const status = (u.account_status || u.accountStatus || 'APPROVED').toUpperCase();
      const birthDateVal = u.birth_date ? String(u.birth_date).substring(0, 10) : '';

      // Normalize phone number to strip leading 62 or 0
      let rawPhone = String(u.phone_number || u.phoneNumber || '').trim();
      if (rawPhone.startsWith('+62')) rawPhone = rawPhone.substring(3);
      else if (rawPhone.startsWith('62')) rawPhone = rawPhone.substring(2);
      else if (rawPhone.startsWith('0')) rawPhone = rawPhone.substring(1);

      const uName = u.full_name || u.fullName || 'Pengguna';

      return `
        <div class="fixed inset-0 z-50 bg-slate-900/40 backdrop-blur-xs flex items-center justify-center p-4 overflow-y-auto animate-fade-in">
          <div class="bg-white rounded-2xl max-w-2xl w-full max-h-[92vh] overflow-y-auto shadow-xl border border-slate-200 custom-scrollbar my-8 overflow-hidden">
            
            <!-- Modal Header -->
            ${renderEditUserHeader(u, uName, status, roleCode)}
            </div>

            <!-- Form Content -->
            <div class="p-6 lg:p-7 space-y-5 text-xs">
              ${state.editFormError ? `
                <div class="p-4 rounded-2xl bg-rose-50 border border-rose-200 text-rose-800 text-xs font-bold flex items-start space-x-2.5 shadow-xs">
                  <i data-lucide="alert-circle" class="w-4 h-4 flex-shrink-0 text-rose-600 mt-0.5"></i>
                  <div class="flex-1">
                    <p class="font-black text-rose-900">Peringatan Validasi</p>
                    <p class="text-rose-700 font-semibold mt-0.5">${state.editFormError}</p>
                  </div>
                </div>
              ` : ''}

              <form id="editUserForm" onsubmit="handleSaveProfile(event)" class="space-y-5">
                
                <!-- Section 1: Identitas Pribadi & Kontak -->
                <div class="bg-slate-50/80 p-5 rounded-2xl border border-slate-200/80 space-y-4 shadow-xs">
                  <h4 class="font-extrabold text-blue-950 flex items-center text-xs pb-1 border-b border-slate-200/60">
                    <i data-lucide="user" class="w-4 h-4 mr-1.5 text-blue-700"></i>
                    1. Data Identitas Pribadi & Kontak
                  </h4>
                  
                  <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                    <div class="md:col-span-2">
                      <label class="block font-extrabold text-slate-700 mb-1.5">Nama Lengkap *</label>
                      <input type="text" id="editFullName" required value="${u.full_name || u.fullName || ''}" placeholder="Masukkan nama lengkap..."
                        class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl font-bold text-slate-900 text-xs focus:outline-none focus:ring-2 focus:ring-amber-500 focus:border-amber-500 shadow-xs transition" />
                    </div>

                    <div>
                      <label class="block font-extrabold text-slate-700 mb-1.5">Alamat Email *</label>
                      <input type="email" id="editEmail" required value="${u.email || ''}" placeholder="nama@email.com"
                        class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl font-semibold text-slate-900 text-xs focus:outline-none focus:ring-2 focus:ring-amber-500 focus:border-amber-500 shadow-xs transition" />
                    </div>

                    <!-- WhatsApp with +62 Badge & Realtime Validation -->
                    <div>
                      <label class="block font-extrabold text-slate-700 mb-1.5">Nomor WhatsApp / HP *</label>
                      <div class="relative rounded-xl shadow-xs">
                        <div class="absolute inset-y-0 left-0 pl-3.5 flex items-center pointer-events-none">
                          <span class="text-xs mr-1">🇮🇩</span>
                          <span class="text-xs font-black text-slate-800 border-r border-slate-200 pr-2">+62</span>
                        </div>
                        <input type="tel" id="editPhone" required value="${rawPhone}" placeholder="81234567890"
                          oninput="onEditPhoneInput(this)"
                          class="block w-full pl-16 pr-4 py-2.5 bg-white border border-slate-200 rounded-xl font-black text-slate-900 text-xs focus:outline-none focus:ring-2 focus:ring-amber-500 focus:border-amber-500 transition" />
                      </div>
                    </div>

                    <div>
                      <label class="block font-extrabold text-slate-700 mb-1.5">Tanggal Lahir</label>
                      <input type="date" id="editBirthDate" value="${birthDateVal}"
                        class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl font-semibold text-slate-900 text-xs focus:outline-none focus:ring-2 focus:ring-amber-500 focus:border-amber-500 shadow-xs transition" />
                    </div>

                    <div>
                      <label class="block font-extrabold text-slate-700 mb-1.5">Alamat Lengkap Domisili</label>
                      <input type="text" id="editAddress" value="${u.address || ''}" placeholder="Jl. Mawar No. 12..."
                        class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl font-semibold text-slate-900 text-xs focus:outline-none focus:ring-2 focus:ring-amber-500 focus:border-amber-500 shadow-xs transition" />
                    </div>
                  </div>
                </div>

                <!-- Section 2: Peran & Status Akun -->
                <div class="bg-slate-50/80 p-5 rounded-2xl border border-slate-200/80 space-y-4 shadow-xs">
                  <h4 class="font-extrabold text-blue-950 flex items-center text-xs pb-1 border-b border-slate-200/60">
                    <i data-lucide="shield" class="w-4 h-4 mr-1.5 text-blue-700"></i>
                    2. Peran & Status Verifikasi Akun
                  </h4>

                  <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                    <div>
                      <label class="block font-extrabold text-slate-700 mb-1.5">Peran / Role Pengguna</label>
                      <select id="editRoleCode" onchange="syncEditFormToState(); state.activeEditUser.role_code = this.value; renderApp();"
                        ${roleCode === 'SUPERADMIN' && (typeof isSuperAdminUser === 'function' && !isSuperAdminUser()) ? 'disabled' : ''}
                        class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl font-black text-blue-950 text-xs focus:outline-none focus:ring-2 focus:ring-amber-500 focus:border-amber-500 shadow-xs transition">
                        <option value="UMAT" ${roleCode === 'UMAT' ? 'selected' : ''}>Umat Katolik</option>
                        <option value="PENGURUS_LINGKUNGAN" ${roleCode === 'PENGURUS_LINGKUNGAN' ? 'selected' : ''}>Pengurus Lingkungan</option>
                        <option value="ROMO_PAROKI" ${roleCode === 'ROMO_PAROKI' ? 'selected' : ''}>Romo Paroki (Diosesan)</option>
                        <option value="ROMO_ORDO" ${roleCode === 'ROMO_ORDO' ? 'selected' : ''}>Romo Ordo (Religius)</option>
                        <option value="ADMIN" ${roleCode === 'ADMIN' ? 'selected' : ''}>Administrator</option>
                        ${(typeof isSuperAdminUser === 'function' && isSuperAdminUser()) || roleCode === 'SUPERADMIN' ? `<option value="SUPERADMIN" ${roleCode === 'SUPERADMIN' ? 'selected' : ''}>Super Admin</option>` : ''}
                      </select>
                    </div>

                    <div>
                      <label class="block font-extrabold text-slate-700 mb-1.5">Status Akun</label>
                      <select id="editAccountStatus" onchange="syncEditFormToState(); state.activeEditUser.account_status = this.value;"
                        class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl font-black text-slate-900 text-xs focus:outline-none focus:ring-2 focus:ring-amber-500 focus:border-amber-500 shadow-xs transition">
                        <option value="APPROVED" ${status === 'APPROVED' ? 'selected' : ''}>APPROVED (Aktif & Terverifikasi)</option>
                        <option value="PENDING_APPROVAL" ${status === 'PENDING_APPROVAL' ? 'selected' : ''}>PENDING_APPROVAL (Menunggu Persetujuan)</option>
                        <option value="REJECTED" ${status === 'REJECTED' ? 'selected' : ''}>REJECTED (Ditolak)</option>
                        <option value="BLOCKED" ${status === 'BLOCKED' ? 'selected' : ''}>BLOCKED (Diblokir)</option>
                      </select>
                    </div>
                  </div>
                </div>

                <!-- Section 3: Domisili Wilayah & Gereja -->
                <div class="bg-slate-50/80 p-5 rounded-2xl border border-slate-200/80 space-y-4 shadow-xs">
                  <div class="pb-1 border-b border-slate-200/60">
                    <h4 class="font-extrabold text-blue-950 flex items-center text-xs">
                      <i data-lucide="church" class="w-4 h-4 mr-1.5 text-blue-700"></i>
                      3. Domisili Wilayah Administratif & Gereja
                    </h4>
                  </div>

                  <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                    <!-- Provinsi Combobox -->
                    ${renderCustomCombobox({
                      id: 'editProvinsiId',
                      name: 'editProvinsi',
                      label: 'Provinsi',
                      icon: 'map',
                      badgeText: `${(state.provinsi || []).length} Provinsi`,
                      placeholder: '-- Pilih Provinsi --',
                      searchPlaceholder: 'Cari nama Provinsi...',
                      options: (state.provinsi || []).map(p => ({ id: p.id, name: p.name })),
                      selectedValue: u.provinsi_id,
                      onSelectCallback: 'onEditProvinsiSelected',
                      onClearCallback: 'onEditProvinsiCleared',
                    })}

                    <!-- Kabupaten/Kota Combobox -->
                    ${renderCustomCombobox({
                      id: 'editKabupatenKotaId',
                      name: 'editKabupatenKota',
                      label: 'Kabupaten / Kota',
                      icon: 'building-2',
                      badgeText: `${(state.editKabupatenKotaList && state.editKabupatenKotaList.length > 0 ? state.editKabupatenKotaList : (state.kabupatenKota || [])).length} Kota/Kab`,
                      placeholder: '-- Pilih Kabupaten/Kota --',
                      searchPlaceholder: 'Cari Kota atau Kabupaten...',
                      options: (state.editKabupatenKotaList && state.editKabupatenKotaList.length > 0 ? state.editKabupatenKotaList : (state.kabupatenKota || [])).map(k => ({ id: k.id, name: k.name })),
                      selectedValue: u.kabupaten_kota_id,
                      onSelectCallback: 'onEditKabupatenKotaSelected',
                      onClearCallback: 'onEditKabupatenKotaCleared',
                    })}

                    ${roleCode !== 'ROMO_ORDO' ? `
                      <!-- Keuskupan Combobox -->
                      ${renderCustomCombobox({
                        id: 'editKeuskupanId',
                        name: 'editKeuskupan',
                        label: 'Keuskupan',
                        icon: 'landmark',
                        badgeText: `${(state.keuskupan || []).length} Keuskupan`,
                        placeholder: '-- Pilih Keuskupan --',
                        searchPlaceholder: 'Cari nama Keuskupan...',
                        options: (state.keuskupan || []).map(k => ({ id: k.id, name: k.name })),
                        selectedValue: u.keuskupan_id,
                        onSelectCallback: 'onEditKeuskupanSelected',
                        onClearCallback: 'onEditKeuskupanCleared',
                      })}

                      <!-- Paroki Combobox -->
                      ${renderCustomCombobox({
                        id: 'editParokiId',
                        name: 'editParoki',
                        label: 'Paroki',
                        icon: 'church',
                        badgeText: `${(state.editParokiList && state.editParokiList.length > 0 ? state.editParokiList : (state.paroki || [])).length} Paroki`,
                        placeholder: '-- Pilih Paroki --',
                        searchPlaceholder: 'Cari nama Paroki...',
                        options: (state.editParokiList && state.editParokiList.length > 0 ? state.editParokiList : (state.paroki || [])).map(p => ({ id: p.id, name: p.name })),
                        selectedValue: u.paroki_id,
                        onSelectCallback: 'onEditParokiSelected',
                        onClearCallback: 'onEditParokiCleared',
                      })}

                      <!-- Wilayah Combobox -->
                      ${renderCustomCombobox({
                        id: 'editWilayahId',
                        name: 'editWilayah',
                        label: 'Wilayah',
                        icon: 'map-pin',
                        badgeText: `${(state.editWilayahList || []).length} Wilayah`,
                        placeholder: (state.editWilayahList || []).length === 0 ? '-- Pilih Paroki terlebih dahulu --' : '-- Pilih Wilayah --',
                        searchPlaceholder: 'Cari nama Wilayah...',
                        options: (state.editWilayahList || []).map(w => ({ id: w.id, name: w.name })),
                        selectedValue: u.wilayah_id,
                        onSelectCallback: 'onEditWilayahSelected',
                        onClearCallback: 'onEditWilayahCleared',
                        disabled: !u.paroki_id
                      })}

                      <!-- Lingkungan Combobox -->
                      ${renderCustomCombobox({
                        id: 'editLingkunganId',
                        name: 'editLingkungan',
                        label: 'Lingkungan',
                        icon: 'home',
                        badgeText: `${(state.editLingkunganList || []).length} Lingkungan`,
                        placeholder: (state.editLingkunganList || []).length === 0 ? '-- Pilih Wilayah terlebih dahulu --' : '-- Pilih Lingkungan --',
                        searchPlaceholder: 'Cari nama Lingkungan...',
                        options: (state.editLingkunganList || []).map(l => ({ id: l.id, name: l.name })),
                        selectedValue: u.lingkungan_id,
                        onSelectCallback: 'onEditLingkunganSelected',
                        onClearCallback: 'onEditLingkunganCleared',
                        disabled: !u.wilayah_id
                      })}
                    ` : `
                      <!-- Ordo Combobox -->
                      <div class="md:col-span-2">
                        ${renderCustomCombobox({
                          id: 'editOrdoId',
                          name: 'editOrdo',
                          label: 'Ordo / Kongregasi Religius',
                          icon: 'cross',
                          badgeText: `${(state.ordo || []).length} Ordo`,
                          placeholder: '-- Pilih Ordo / Kongregasi --',
                          searchPlaceholder: 'Cari nama atau kode singkatan Ordo...',
                          options: (state.ordo || []).map(o => ({ id: o.id, name: o.name, code: o.code })),
                          selectedValue: u.ordo_id,
                          onSelectCallback: 'onEditOrdoSelected',
                          onClearCallback: 'onEditOrdoCleared',
                        })}
                      </div>
                    `}
                  </div>
                </div>

                <!-- Section 4: Data Kepengurusan (Kondisional) -->
                ${(roleCode === 'PENGURUS_LINGKUNGAN' || (u.pengurus_position || '').toLowerCase().includes('koordinator')) ? `
                  <div class="bg-blue-50/40 p-5 rounded-2xl border border-blue-100/80 space-y-4 shadow-xs">
                    <h4 class="font-extrabold text-blue-950 flex items-center text-xs pb-1 border-b border-blue-100/80">
                      <i data-lucide="briefcase" class="w-4 h-4 mr-1.5 text-blue-700"></i>
                      4. Data Kepengurusan / Koordinator
                    </h4>
                    <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
                      <div>
                        <label class="block font-extrabold text-slate-700 mb-1.5">Jabatan Pengurus / Koordinator *</label>
                        <select id="editPengurusPosition" class="w-full px-3.5 py-2.5 bg-white border border-slate-200 rounded-xl font-bold text-slate-900 text-xs focus:outline-none focus:ring-2 focus:ring-blue-500 shadow-xs">
                          <option value="Ketua Lingkungan" ${u.pengurus_position === 'Ketua Lingkungan' ? 'selected' : ''}>Ketua Lingkungan (Pimpinan)</option>
                          <option value="Wakil Ketua" ${u.pengurus_position === 'Wakil Ketua' ? 'selected' : ''}>Wakil Ketua</option>
                          <option value="Sekretaris" ${u.pengurus_position === 'Sekretaris' ? 'selected' : ''}>Sekretaris</option>
                          <option value="Koordinator" ${u.pengurus_position === 'Koordinator' ? 'selected' : ''}>Koordinator (Keuskupan)</option>
                        </select>
                      </div>
                      <div>
                        <label class="block font-extrabold text-slate-700 mb-1.5">Tahun Mulai</label>
                        <input type="number" id="editJabatanStartYear" value="${u.jabatan_start_year || 2024}" class="w-full px-3.5 py-2.5 bg-white border border-slate-200 rounded-xl font-bold text-slate-900 text-xs focus:outline-none focus:ring-2 focus:ring-blue-500 shadow-xs" />
                      </div>
                      <div>
                        <label class="block font-extrabold text-slate-700 mb-1.5">Tahun Selesai</label>
                        <input type="number" id="editJabatanEndYear" value="${u.jabatan_end_year || 2027}" class="w-full px-3.5 py-2.5 bg-white border border-slate-200 rounded-xl font-bold text-slate-900 text-xs focus:outline-none focus:ring-2 focus:ring-blue-500 shadow-xs" />
                      </div>
                    </div>
                  </div>
                ` : ''}

                ${roleCode === 'ROMO_PAROKI' ? (() => {
                  const pId = u.paroki_id || u.parokiId;
                  const existK = pId ? state.users.find(o => String(o.id) !== String(u.id) && (o.role_code || o.roleCode || '').toUpperCase() === 'ROMO_PAROKI' && (o.account_status || o.accountStatus || '').toUpperCase() === 'APPROVED' && String(o.paroki_id || o.parokiId) === String(pId) && ((o.romo_position || o.romoPosition || '').toLowerCase().includes('kepala') || (o.romo_position || o.romoPosition || '').toUpperCase() === 'KETUA_ROMO')) : null;
                  const isK = (u.romo_position || '').toLowerCase().includes('kepala') || (u.romo_position || '').toUpperCase() === 'KETUA_ROMO';
                  return `
                  <div class="bg-blue-50/40 p-5 rounded-2xl border border-blue-100/80 space-y-4 shadow-xs">
                    <h4 class="font-extrabold text-blue-950 flex items-center text-xs pb-1 border-b border-blue-100/80">
                      <i data-lucide="church" class="w-4 h-4 mr-1.5 text-blue-700"></i>
                      4. Posisi Pastoral Romo Paroki
                    </h4>
                    <div>
                      <label class="block font-extrabold text-slate-700 mb-1.5">Jabatan Pastoral *</label>
                      <select id="editRomoPosition" class="w-full px-3.5 py-2.5 bg-white border border-slate-200 rounded-xl font-bold text-slate-900 text-xs focus:outline-none focus:ring-2 focus:ring-blue-500 shadow-xs">
                        <option value="Kepala Romo Paroki" ${isK ? 'selected' : (existK ? 'disabled class="text-slate-400 bg-slate-100"' : '')}>Kepala Romo Paroki (Pimpinan Paroki)${existK && !isK ? ` — Sudah ada: ${existK.full_name || existK.fullName}` : ''}</option>
                        <option value="Romo Paroki" ${!isK ? 'selected' : ''}>Romo Paroki (Pastor Rekan)</option>
                      </select>
                      ${existK && !isK ? `<p class="text-[11px] text-amber-700 font-semibold mt-1.5 flex items-center gap-1"><i data-lucide="alert-circle" class="w-3.5 h-3.5"></i> Paroki ini sudah memiliki Kepala Romo Paroki (${existK.full_name || existK.fullName}). Hanya boleh 1 Kepala per paroki.</p>` : `<p class="text-[10.5px] text-slate-500 mt-1">Maksimal 1 Kepala Romo Paroki per paroki.</p>`}
                    </div>
                  </div>`;
                })() : ''}

                ${roleCode === 'ROMO_ORDO' ? `
                  <div class="bg-blue-50/40 p-5 rounded-2xl border border-blue-100/80 space-y-4 shadow-xs">
                    <h4 class="font-extrabold text-blue-950 flex items-center text-xs pb-1 border-b border-blue-100/80">
                      <i data-lucide="cross" class="w-4 h-4 mr-1.5 text-blue-700"></i>
                      4. Posisi Struktur Romo Ordo
                    </h4>
                    <div>
                      <label class="block font-extrabold text-slate-700 mb-1.5">Jabatan di Ordo / Kongregasi *</label>
                      <select id="editRomoOrdoPosition" class="w-full px-3.5 py-2.5 bg-white border border-slate-200 rounded-xl font-bold text-slate-900 text-xs focus:outline-none focus:ring-2 focus:ring-blue-500 shadow-xs">
                        <option value="Ketua Romo Ordo" ${u.romo_position === 'Ketua Romo Ordo' ? 'selected' : ''}>Ketua Romo Ordo (Pimpinan / Provinsial)</option>
                        <option value="Romo Ordo" ${u.romo_position === 'Romo Ordo' || !u.romo_position ? 'selected' : ''}>Romo Ordo (Imam Anggota)</option>
                      </select>
                    </div>
                  </div>
                ` : ''}

                <div class="pt-5 border-t border-slate-200 flex items-center justify-end space-x-3">
                  <button type="button" onclick="state.activeEditUser = null; renderApp();"
                    class="px-5 py-2.5 rounded-xl bg-slate-100 hover:bg-slate-200 text-slate-700 font-extrabold text-xs transition">
                    Batal
                  </button>
                  <button type="submit" ${state.isSavingProfile ? 'disabled' : ''}
                    class="px-6 py-2.5 rounded-xl bg-blue-950 hover:bg-blue-900 text-white font-bold text-xs flex items-center space-x-2 shadow-xs transition disabled:opacity-50">
                    ${state.isSavingProfile ? `
                      <span class="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin"></span>
                      <span>Menyimpan Perubahan...</span>
                    ` : `
                      <i data-lucide="save" class="w-4 h-4"></i>
                      <span>Simpan Perubahan</span>
                    `}
                  </button>
                </div>
              </form>
            </div>
          </div>
        </div>
      `;
    }
