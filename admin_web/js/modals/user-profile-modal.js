// ── User Profile View Modal ──
    function renderUserProfileModal() {
      const u = state.activeUserProfile;
      if (!u) return '';
      const uName = u.full_name || u.fullName || 'Pengguna';
      const uPhone = u.phone_number || u.phoneNumber || '-';
      const uRole = u.role_name || u.role_code || u.roleCode || 'Pengguna';
      const uRoleCode = (u.role_code || u.roleCode || '').toUpperCase();
      const uPar = u.paroki_name || u.parokiName || '-';
      const uWil = u.wilayah_name || u.wilayahName || '-';
      const uLing = u.lingkungan_name || u.lingkunganName || '-';
      const uStatus = (u.account_status || u.accountStatus || 'APPROVED').toUpperCase();
      const uEmail = u.email || '-';
      const uBirth = u.birth_date || u.birthDate || '-';
      const uAddr = u.address || '-';
      
      const startY = u.jabatan_start_year || (u.jabatan_start_date ? new Date(u.jabatan_start_date).getFullYear() : null);
      const endY = u.jabatan_end_year || (u.jabatan_end_date ? new Date(u.jabatan_end_date).getFullYear() : null);
      const periode = (startY && endY) ? `${startY} - ${endY}` : (startY ? `${startY} - Sekarang` : 'Aktif');

      const initial = uName.charAt(0).toUpperCase();

      return `
        <div class="fixed inset-0 z-50 bg-black/60 backdrop-blur-sm flex items-center justify-center p-4 overflow-y-auto animate-fade-in">
          <div class="bg-white rounded-3xl max-w-lg w-full shadow-2xl border border-slate-200 overflow-hidden my-8">
            <!-- Modal Header with Banner & Avatar -->
            <div class="bg-gradient-to-r from-blue-950 via-slate-900 to-indigo-950 p-6 text-white relative">
              <button onclick="state.activeUserProfile = null; renderApp();" class="absolute top-4 right-4 p-2 rounded-full bg-white/10 hover:bg-white/20 text-white/80 hover:text-white transition">
                <i data-lucide="x" class="w-4 h-4"></i>
              </button>
              
              <div class="flex items-center space-x-4">
                <div class="w-14 h-14 rounded-2xl bg-amber-500 text-white font-extrabold text-2xl flex items-center justify-center shadow-lg border-2 border-white/20">
                  ${initial}
                </div>
                <div>
                  <div class="flex items-center space-x-2 mb-1">
                    <h3 class="text-lg font-extrabold text-white leading-tight">${uName}</h3>
                    <span class="px-2.5 py-0.5 rounded-full text-[10px] font-black tracking-wide ${uStatus === 'APPROVED' ? 'bg-emerald-500 text-white' : 'bg-amber-400 text-slate-900'}">
                      ${uStatus}
                    </span>
                  </div>
                  <div class="flex items-center space-x-2 text-xs text-slate-300">
                    <span class="inline-flex items-center text-amber-300 font-bold">
                      <i data-lucide="shield" class="w-3.5 h-3.5 mr-1"></i>
                      ${uRole}
                    </span>
                    <span>•</span>
                    <span>ID #${u.id}</span>
                  </div>
                </div>
              </div>
            </div>

            <!-- Modal Content Body -->
            <div class="p-6 space-y-5 max-h-[70vh] overflow-y-auto text-xs">
              
              <!-- Section 1: Kontak & Biodata -->
              <div class="bg-slate-50/80 rounded-2xl p-4 border border-slate-200/80 space-y-2.5">
                <p class="font-extrabold text-slate-900 text-xs flex items-center text-blue-950">
                  <i data-lucide="user" class="w-3.5 h-3.5 mr-1.5 text-blue-600"></i>
                  Informasi Kontak & Akun
                </p>
                <div class="grid grid-cols-1 md:grid-cols-2 gap-2.5 pt-1">
                  <div class="bg-white p-2.5 rounded-xl border border-slate-200/60">
                    <p class="text-[10px] font-bold text-slate-400 uppercase">No. WhatsApp</p>
                    <p class="font-extrabold text-slate-900 mt-0.5 flex items-center text-xs">
                      <i data-lucide="phone" class="w-3 h-3 mr-1 text-emerald-600"></i>
                      ${uPhone}
                    </p>
                  </div>
                  <div class="bg-white p-2.5 rounded-xl border border-slate-200/60">
                    <p class="text-[10px] font-bold text-slate-400 uppercase">Email</p>
                    <p class="font-bold text-slate-800 mt-0.5 truncate text-xs">
                      ${uEmail}
                    </p>
                  </div>
                  <div class="bg-white p-2.5 rounded-xl border border-slate-200/60">
                    <p class="text-[10px] font-bold text-slate-400 uppercase">Tanggal Lahir</p>
                    <p class="font-bold text-slate-800 mt-0.5 text-xs">
                      ${uBirth}
                    </p>
                  </div>
                  <div class="bg-white p-2.5 rounded-xl border border-slate-200/60">
                    <p class="text-[10px] font-bold text-slate-400 uppercase">Domisili Kota</p>
                    <p class="font-bold text-slate-800 mt-0.5 text-xs">
                      ${u.kota_name || u.kabupatenKotaName || 'JAKARTA TIMUR'}
                    </p>
                  </div>
                </div>
                ${uAddr !== '-' ? `
                  <div class="bg-white p-2.5 rounded-xl border border-slate-200/60 mt-2">
                    <p class="text-[10px] font-bold text-slate-400 uppercase">Alamat Lengkap</p>
                    <p class="font-medium text-slate-700 mt-0.5 text-xs">${uAddr}</p>
                  </div>
                ` : ''}
              </div>

              <!-- Section 2: Keanggotaan Gereja / Domisili Pastoral -->
              ${uRoleCode !== 'ROMO_ORDO' ? `
                <div class="bg-blue-50/50 rounded-2xl p-4 border border-blue-100 space-y-2.5">
                  <p class="font-extrabold text-blue-950 text-xs flex items-center">
                    <i data-lucide="church" class="w-3.5 h-3.5 mr-1.5 text-blue-700"></i>
                    Wilayah & Lingkungan Gereja
                  </p>
                  <div class="grid grid-cols-1 md:grid-cols-2 gap-2.5 pt-1">
                    <div class="bg-white p-2.5 rounded-xl border border-blue-100/80">
                      <p class="text-[10px] font-bold text-slate-400 uppercase">Paroki</p>
                      <p class="font-extrabold text-blue-950 mt-0.5 text-xs">${uPar}</p>
                    </div>
                    <div class="bg-white p-2.5 rounded-xl border border-blue-100/80">
                      <p class="text-[10px] font-bold text-slate-400 uppercase">Keuskupan</p>
                      <p class="font-bold text-slate-800 mt-0.5 text-xs">${u.keuskupan_name || u.keuskupanName || 'Keuskupan Agung Jakarta'}</p>
                    </div>
                    <div class="bg-white p-2.5 rounded-xl border border-blue-100/80">
                      <p class="text-[10px] font-bold text-slate-400 uppercase">Wilayah</p>
                      <p class="font-bold text-slate-800 mt-0.5 text-xs">${uWil}</p>
                    </div>
                    <div class="bg-white p-2.5 rounded-xl border border-blue-100/80">
                      <p class="text-[10px] font-bold text-slate-400 uppercase">Lingkungan</p>
                      <p class="font-bold text-slate-800 mt-0.5 text-xs">${uLing}</p>
                    </div>
                  </div>
                </div>
              ` : `
                <div class="bg-purple-50/50 rounded-2xl p-4 border border-purple-100 space-y-2.5">
                  <p class="font-extrabold text-purple-950 text-xs flex items-center">
                    <i data-lucide="cross" class="w-3.5 h-3.5 mr-1.5 text-purple-700"></i>
                    Ordo Religius
                  </p>
                  <div class="bg-white p-3 rounded-xl border border-purple-100/80">
                    <p class="text-[10px] font-bold text-slate-400 uppercase">Nama Ordo</p>
                    <p class="font-extrabold text-purple-950 mt-0.5 text-sm">${u.ordo_name || u.ordoName || '-'}</p>
                  </div>
                </div>
              `}

              <!-- Section 3: Jabatan Kepengurusan / Pastoral (Khusus Pengurus & Romo) -->
              ${uRoleCode === 'PENGURUS_LINGKUNGAN' ? `
                <div class="bg-indigo-50/50 rounded-2xl p-4 border border-indigo-100 space-y-2.5">
                  <p class="font-extrabold text-indigo-950 text-xs flex items-center">
                    <i data-lucide="award" class="w-3.5 h-3.5 mr-1.5 text-indigo-700"></i>
                    Detail Jabatan Pengurus Lingkungan
                  </p>
                  <div class="grid grid-cols-1 md:grid-cols-2 gap-2.5 pt-1">
                    <div class="bg-white p-2.5 rounded-xl border border-indigo-100/80">
                      <p class="text-[10px] font-bold text-slate-400 uppercase mb-1">Posisi Kepengurusan</p>
                      ${getUserPositionBadge(u.pengurus_position || 'Ketua Lingkungan', 'PENGURUS_LINGKUNGAN')}
                    </div>
                    <div class="bg-white p-2.5 rounded-xl border border-indigo-100/80">
                      <p class="text-[10px] font-bold text-slate-400 uppercase mb-1">Masa Jabatan</p>
                      <p class="font-extrabold text-amber-800 text-xs flex items-center">
                        <i data-lucide="calendar" class="w-3 h-3 mr-1 text-amber-600"></i>
                        ${periode}
                      </p>
                    </div>
                  </div>
                </div>
              ` : ''}

              ${uRoleCode === 'ROMO_PAROKI' ? `
                <div class="bg-emerald-50/50 rounded-2xl p-4 border border-emerald-100 space-y-2.5">
                  <p class="font-extrabold text-emerald-950 text-xs flex items-center">
                    <i data-lucide="award" class="w-3.5 h-3.5 mr-1.5 text-emerald-700"></i>
                    Detail Jabatan Pastoral Paroki
                  </p>
                  <div class="bg-white p-3 rounded-xl border border-emerald-100/80">
                    <p class="text-[10px] font-bold text-slate-400 uppercase mb-1">Posisi Pastoral</p>
                    ${getUserPositionBadge(u.romo_position || 'Romo Paroki', 'ROMO_PAROKI')}
                  </div>
                </div>
              ` : ''}

              ${uRoleCode === 'ROMO_ORDO' ? `
                <div class="bg-purple-50/50 rounded-2xl p-4 border border-purple-100 space-y-2.5">
                  <p class="font-extrabold text-purple-950 text-xs flex items-center">
                    <i data-lucide="award" class="w-3.5 h-3.5 mr-1.5 text-purple-700"></i>
                    Detail Jabatan di Ordo Religius
                  </p>
                  <div class="bg-white p-3 rounded-xl border border-purple-100/80">
                    <p class="text-[10px] font-bold text-slate-400 uppercase mb-1">Posisi di Ordo</p>
                    ${getUserPositionBadge(u.romo_position || 'Romo Ordo', 'ROMO_ORDO')}
                  </div>
                </div>
              ` : ''}

            </div>

            <!-- Modal Footer Buttons -->
            <div class="p-5 bg-slate-50 border-t border-slate-200 flex justify-end space-x-2">
              <button onclick="state.activeUserProfile = null; openEditUserModal('${u.id}');"
                class="inline-flex items-center space-x-1.5 px-4 py-2.5 rounded-xl bg-amber-500 hover:bg-amber-600 text-white text-xs font-extrabold shadow-sm hover:shadow-md transition transform hover:-translate-y-0.5">
                <i data-lucide="edit" class="w-3.5 h-3.5"></i>
                <span>Edit Profil</span>
              </button>
              <button onclick="state.activeUserProfile = null; renderApp();"
                class="inline-flex items-center space-x-1.5 px-4 py-2.5 rounded-xl bg-blue-950 hover:bg-slate-900 text-white text-xs font-extrabold transition">
                <span>Tutup</span>
              </button>
            </div>
          </div>
        </div>
      `;
    }


    function viewUserProfileModal(userId) {
      state.activeUserProfile = state.users.find(u => String(u.id) === String(userId));
      renderApp();
    }

    // Global Click Listener to close combobox dropdowns on outside click
    window.addEventListener('click', (e) => {
      if (state.openCombobox && !e.target.closest('.custom-combobox-container')) {
        state.openCombobox = null;
        renderApp();
      }
    });

    // Init
    renderApp();
    if (state.currentUser && (state.currentUser.roleCode === 'ADMIN' || state.currentUser.role_code === 'ADMIN')) {
      loadDashboardData();
    }
