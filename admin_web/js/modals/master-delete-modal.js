// ── Delete Confirmation Modal for Master Data ──
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
