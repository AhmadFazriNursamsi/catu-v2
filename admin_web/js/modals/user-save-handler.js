// ── User Edit Open & Save Handlers ──
function renderEditUserHeader(u, uName, status, roleCode) {
  return `<div class="p-6 border-b border-slate-100 flex items-start justify-between gap-4">
              <div class="flex items-center space-x-3.5 min-w-0">
                <div class="w-11 h-11 rounded-xl bg-slate-100 border border-slate-200 text-slate-700 flex items-center justify-center flex-shrink-0">
                  <i data-lucide="user-cog" class="w-5 h-5 text-slate-600"></i>
                </div>
                <div class="min-w-0">
                  <div class="flex flex-wrap items-center gap-2 mb-1">
                    <h3 class="text-base font-bold text-slate-900 tracking-tight">Perbarui Profil Pengguna</h3>
                    <span class="inline-flex items-center space-x-1 px-2 py-0.5 rounded-full text-[10px] font-bold ${status === 'APPROVED' ? 'bg-emerald-50 text-emerald-800 border border-emerald-200' : 'bg-amber-50 text-amber-800 border border-amber-200'}">
                      <span class="w-1.5 h-1.5 rounded-full ${status === 'APPROVED' ? 'bg-emerald-500' : 'bg-amber-500'}"></span>
                      <span>${status}</span>
                    </span>
                  </div>
                  <div class="flex items-center space-x-2 text-xs text-slate-500 font-medium">
                    <span class="font-bold text-slate-800 truncate">${uName}</span>
                    <span>•</span>
                    <span class="px-1.5 py-0.5 rounded bg-slate-100 text-slate-600 font-bold text-[10px]">${roleCode}</span>
                  </div>
                </div>
              </div>
              <button onclick="state.activeEditUser = null; renderApp();" 
                class="p-1.5 text-slate-400 hover:text-slate-700 hover:bg-slate-100 rounded-lg transition"
                title="Tutup">
                <i data-lucide="x" class="w-5 h-5"></i>
              </button>`;
}

    function onEditPhoneInput(input) {
      let val = input.value.replace(/\D/g, '');
      if (val.startsWith('62')) val = val.substring(2);
      if (val.startsWith('0')) val = val.substring(1);
      if (val.length > 0 && !val.startsWith('8')) {
        val = '8' + val.replace(/^[^8]+/, '');
      }
      input.value = val;
    }


    async function openEditUserModal(userId) {
      const u = state.users.find(x => String(x.id) === String(userId));
      if (!u) return;
      state.activeEditUser = { ...u };
      state.editFormError = '';
      state.comboboxFilters = {};

      try {
        // Preload lookups if needed
        if (!state.provinsi || state.provinsi.length === 0) {
          const pRes = await fetch(`${API_BASE}/auth/provinsi`);
          state.provinsi = await pRes.json();
        }
        if (!state.keuskupan || state.keuskupan.length === 0) {
          const kRes = await fetch(`${API_BASE}/auth/keuskupan`);
          state.keuskupan = await kRes.json();
        }
        if (!state.ordo || state.ordo.length === 0) {
          const oRes = await fetch(`${API_BASE}/auth/ordo`);
          state.ordo = await oRes.json();
        }

        // Preload kabupaten-kota list
        const kkUrl = u.provinsi_id ? `${API_BASE}/auth/kabupaten-kota?provinsiId=${u.provinsi_id}` : `${API_BASE}/auth/kabupaten-kota`;
        const kkRes = await fetch(kkUrl);
        state.editKabupatenKotaList = await kkRes.json();

        // Preload paroki list
        const parUrl = u.keuskupan_id ? `${API_BASE}/auth/paroki?keuskupanId=${u.keuskupan_id}` : `${API_BASE}/auth/paroki`;
        const parRes = await fetch(parUrl);
        state.editParokiList = await parRes.json();

        // Load cascading wilayah
        if (u.paroki_id) {
          const wRes = await fetch(`${API_BASE}/auth/wilayah?parokiId=${u.paroki_id}`);
          state.editWilayahList = await wRes.json();
        } else {
          state.editWilayahList = [];
        }

        // Load cascading lingkungan
        if (u.wilayah_id) {
          const lRes = await fetch(`${API_BASE}/auth/lingkungan?wilayahId=${u.wilayah_id}`);
          state.editLingkunganList = await lRes.json();
        } else {
          state.editLingkunganList = [];
        }
      } catch (err) {
        console.error('Error preloading user profile dropdown lists:', err);
      }

      renderApp();
    }

    async function handleSaveProfile(e) {
      e.preventDefault();
      const u = state.activeEditUser;
      if (!u) return;

      const fullName = document.getElementById('editFullName').value.trim();
      const email = document.getElementById('editEmail').value.trim();
      const rawPhone = document.getElementById('editPhone').value.trim().replace(/\D/g, '');
      const roleCode = document.getElementById('editRoleCode').value;
      const accountStatus = document.getElementById('editAccountStatus').value;
      if (roleCode === 'SUPERADMIN' && (typeof isSuperAdminUser === 'function' && !isSuperAdminUser())) {
        state.editFormError = 'Hanya Super Admin yang dapat menetapkan peran Super Admin.';
        renderApp();
        return;
      }
      const origRole = (u.role_code || u.roleCode || '').toUpperCase();
      if (origRole === 'SUPERADMIN' && (typeof isSuperAdminUser === 'function' && !isSuperAdminUser())) {
        state.editFormError = 'Hanya Super Admin yang dapat mengubah data akun Super Admin.';
        renderApp();
        return;
      }
      const birthDateInput = document.getElementById('editBirthDate') ? document.getElementById('editBirthDate').value : '';
      const address = document.getElementById('editAddress') ? document.getElementById('editAddress').value.trim() : '';

      // Validate Phone Number (Must start with 8 and be 9-13 digits)
      if (!rawPhone || !rawPhone.startsWith('8')) {
        state.editFormError = 'Nomor WhatsApp wajib diawali angka 8 (setelah kode negara +62).';
        renderApp();
        return;
      }
      if (rawPhone.length < 9 || rawPhone.length > 13) {
        state.editFormError = 'Panjang nomor WhatsApp minimal 9 dan maksimal 13 digit angka.';
        renderApp();
        return;
      }
      const formattedPhone = rawPhone.startsWith('62') ? rawPhone : ('62' + rawPhone);

      // Check if phone number is already used by another user
      const isDuplicatePhone = state.users.some(other => {
        if (String(other.id) === String(u.id)) return false;
        const otherPhone = String(other.phone_number || other.phoneNumber || '').trim().replace(/\D/g, '');
        const cleanOther = otherPhone.startsWith('62') ? otherPhone : ('62' + otherPhone.replace(/^0/, ''));
        return cleanOther === formattedPhone;
      });
      if (isDuplicatePhone) {
        state.editFormError = 'Nomor WhatsApp ini sudah digunakan oleh pengguna lain. Silakan gunakan nomor yang berbeda.';
        renderApp();
        return;
      }

      // Validate Email
      if (!email || !email.includes('@')) {
        state.editFormError = 'Format alamat email tidak valid.';
        renderApp();
        return;
      }

      const payload = {
        fullName,
        email,
        phoneNumber: formattedPhone,
        roleCode,
        accountStatus,
        address,
        birthDate: birthDateInput && birthDateInput.trim() ? birthDateInput.trim() : null,
      };

      const provElem = document.getElementById('editProvinsiId');
      payload.provinsiId = (provElem && provElem.value) ? parseInt(provElem.value) : null;

      const kkElem = document.getElementById('editKabupatenKotaId');
      payload.kabupatenKotaId = (kkElem && kkElem.value) ? parseInt(kkElem.value) : null;

      if (roleCode !== 'ROMO_ORDO') {
        const kElem = document.getElementById('editKeuskupanId');
        payload.keuskupanId = (kElem && kElem.value) ? parseInt(kElem.value) : null;

        const pElem = document.getElementById('editParokiId');
        payload.parokiId = (pElem && pElem.value) ? parseInt(pElem.value) : null;

        const wElem = document.getElementById('editWilayahId');
        payload.wilayahId = (wElem && wElem.value) ? parseInt(wElem.value) : null;

        const lElem = document.getElementById('editLingkunganId');
        payload.lingkunganId = (lElem && lElem.value) ? parseInt(lElem.value) : null;
      } else {
        const oElem = document.getElementById('editOrdoId');
        payload.ordoId = (oElem && oElem.value) ? parseInt(oElem.value) : null;
      }

      if (roleCode === 'PENGURUS_LINGKUNGAN') {
        const pos = document.getElementById('editPengurusPosition');
        if (pos) payload.pengurusPosition = pos.value;
        const sy = document.getElementById('editJabatanStartYear');
        if (sy && sy.value) payload.jabatanStartYear = parseInt(sy.value);
        const ey = document.getElementById('editJabatanEndYear');
        if (ey && ey.value) payload.jabatanEndYear = parseInt(ey.value);
        payload.isJabatanActive = true;

        // Check if another active/pending user already holds this position in the same lingkungan
        const checkLingkunganId = payload.lingkunganId || u.lingkungan_id;
        if (checkLingkunganId && payload.pengurusPosition) {
          const duplicatePengurus = state.users.find(other => {
            if (String(other.id) === String(u.id)) return false;
            const oStatus = (other.account_status || other.accountStatus || '').toUpperCase();
            if (oStatus !== 'APPROVED' && oStatus !== 'PENDING_APPROVAL') return false;
            const oLing = other.lingkungan_id || other.lingkunganId;
            if (String(oLing) !== String(checkLingkunganId)) return false;
            const oPos = (other.pengurus_position || other.pengurusPosition || '').toLowerCase();
            const myPos = payload.pengurusPosition.toLowerCase();
            if (oPos === myPos) return true;
            if (myPos.includes('ketua') && !myPos.includes('wakil') && oPos.includes('ketua') && !oPos.includes('wakil')) return true;
            if (myPos.includes('wakil') && oPos.includes('wakil')) return true;
            if (myPos.includes('sekretaris') && oPos.includes('sekretaris')) return true;
            if (myPos.includes('bendahara') && oPos.includes('bendahara')) return true;
            return false;
          });
          if (duplicatePengurus) {
            state.editFormError = `Jabatan ${payload.pengurusPosition} pada lingkungan ini sudah diisi oleh ${duplicatePengurus.full_name || duplicatePengurus.fullName}. Pengurus dengan jabatan yang sama tidak boleh ganda dalam satu lingkungan.`;
            renderApp();
            return;
          }
        }
      }

      if (roleCode === 'ROMO_PAROKI') {
        const rpos = document.getElementById('editRomoPosition');
        if (rpos) payload.romoPosition = rpos.value;
      }

      state.isSavingProfile = true;
      state.editFormError = '';
      renderApp();

      try {
        const res = await fetch(`${API_BASE}/auth/profile/${u.id}`, {
          method: 'PUT',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(payload),
        });
        const data = await res.json();
        if (res.ok || data.statusCode === 200) {
          state.activeEditUser = null;
          state.isSavingProfile = false;
          state.editFormError = '';
          showToast(`Data profil pengguna "${fullName}" berhasil diperbarui!`, 'success', 'Profil Diperbarui! ✨');
          await loadDashboardData();
        } else {
          const errMsg = Array.isArray(data.message) ? data.message.join(', ') : (data.message || 'Gagal menyimpan profil pengguna.');
          state.editFormError = errMsg;
          state.isSavingProfile = false;
          showToast(errMsg, 'error', 'Gagal Memperbarui Profil');
          renderApp();
        }
      } catch (err) {
        state.editFormError = 'Terjadi kesalahan saat menghubungi server backend.';
        state.isSavingProfile = false;
        showToast('Terjadi kesalahan jaringan atau server backend offline.', 'error', 'Koneksi Gagal');
        renderApp();
      }
    }
