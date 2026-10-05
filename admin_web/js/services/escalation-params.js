// ── Parameter Pelayanan (Master Data): menit eskalasi Romo Paroki → Romo Ordo → Koordinator ──

function renderEscalationParamsCard() {
  const s = state.escalationSettings || { ordoAfterMinutes: 10, koordinatorAfterMinutes: 20 };
  const draft = state.escalationDraft || s;
  const canEdit = typeof isSuperAdminUser === 'function' && isSuperAdminUser();
  const field = (id, label, hint, value) => `
    <label class="block">
      <span class="text-xs font-extrabold text-slate-700">${label}</span>
      <div class="mt-2 flex items-center gap-2">
        <input type="number" id="${id}" min="0" max="1440" step="1" value="${Number(value)}" ${canEdit ? '' : 'disabled'}
          oninput="updateEscalationDraft()"
          class="w-28 rounded-xl border border-slate-200 bg-white px-3 py-2.5 text-sm font-extrabold text-slate-900 focus:outline-none focus:ring-2 focus:ring-slate-400 disabled:bg-slate-50 disabled:text-slate-400" />
        <span class="text-xs font-bold text-slate-500">menit sejak pelayanan dibuat</span>
      </div>
      <span class="mt-1.5 block text-[11px] font-medium leading-relaxed text-slate-500">${hint}</span>
    </label>`;
  return `
    <div class="bg-white rounded-2xl border border-slate-200/90 shadow-sm overflow-hidden" id="master-table-card">
      <div class="p-4 sm:p-6 border-b border-slate-200/80 bg-slate-50/50">
        <h3 class="text-base font-extrabold text-slate-900">Alur Penerimaan Pelayanan</h3>
        <p class="mt-1 max-w-2xl text-xs font-medium leading-relaxed text-slate-500">
          Romo Paroki dapat menerima pelayanan langsung tanpa jeda. Bila belum diterima, pelayanan terbuka untuk Romo Ordo,
          lalu Koordinator diberi tahu untuk mencarikan Romo (yang sudah maupun belum terdaftar di aplikasi).
        </p>
      </div>
      <div class="grid gap-6 p-4 sm:p-6 md:grid-cols-2">
        ${field('escalationOrdoMinutes', 'Terbuka untuk Romo Ordo setelah', 'Sebelum batas ini Romo Ordo tidak melihat dan tidak dapat menerima pelayanan. Pelayanan tanpa paroki (umat pendatang) langsung terbuka.', draft.ordoAfterMinutes)}
        ${field('escalationKoordinatorMinutes', 'Koordinator diberi tahu setelah', 'Koordinator hanya menerima notifikasi pelayanan baru yang belum diterima setelah batas ini. Tidak boleh lebih kecil dari batas Romo Ordo.', draft.koordinatorAfterMinutes)}
      </div>
      <div class="flex items-center justify-between gap-3 border-t border-slate-200/80 bg-slate-50/50 px-4 py-4 sm:px-6">
        <span class="text-[11px] font-semibold text-slate-500">${canEdit ? 'Perubahan berlaku untuk pelayanan yang belum diterima.' : 'Hanya Super Admin yang dapat mengubah parameter ini.'}</span>
        ${canEdit ? `
          <button type="button" onclick="saveEscalationSettings()" ${state.escalationSaving ? 'disabled' : ''}
            class="inline-flex items-center space-x-1.5 px-4 py-2 rounded-xl bg-blue-950 hover:bg-blue-900 text-white text-xs font-bold shadow-xs transition disabled:opacity-60">
            <i data-lucide="save" class="w-4 h-4"></i><span>${state.escalationSaving ? 'Menyimpan...' : 'Simpan'}</span>
          </button>` : ''}
      </div>
    </div>`;
}

function updateEscalationDraft() {
  state.escalationDraft = {
    ordoAfterMinutes: Number(document.getElementById('escalationOrdoMinutes')?.value),
    koordinatorAfterMinutes: Number(document.getElementById('escalationKoordinatorMinutes')?.value),
  };
}

async function saveEscalationSettings() {
  updateEscalationDraft();
  state.escalationSaving = true;
  renderApp();
  try {
    const res = await fetch(`${API_BASE}/master/escalation-settings`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(state.escalationDraft),
    });
    const data = await res.json();
    if (!res.ok) {
      const message = Array.isArray(data.message) ? data.message.join(', ') : data.message;
      showToast(message || 'Gagal menyimpan parameter.', 'error', 'Gagal');
    } else {
      state.escalationSettings = data;
      state.escalationDraft = null;
      showToast('Parameter pelayanan berhasil disimpan.', 'success', 'Tersimpan');
    }
  } catch (err) {
    showToast('Tidak dapat terhubung ke server.', 'error', 'Gagal');
  } finally {
    state.escalationSaving = false;
    renderApp();
  }
}
