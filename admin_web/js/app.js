// ── Main App Dispatcher & Bootstrap ──
    function renderApp() {
      const activeEl = document.activeElement;
      let focusedId = null;
      let selectionStart = null;
      let selectionEnd = null;

      if (activeEl && (activeEl.tagName === 'INPUT' || activeEl.tagName === 'TEXTAREA') && activeEl.id) {
        focusedId = activeEl.id;
        try {
          selectionStart = activeEl.selectionStart;
          selectionEnd = activeEl.selectionEnd;
        } catch (_) {}
      }

      const app = document.getElementById('app');
      const currentRole = (state.currentUser?.roleCode || state.currentUser?.role_code || '').toUpperCase();
      if (!state.currentUser || (!['ADMIN', 'SUPERADMIN'].includes(currentRole))) {
        app.innerHTML = renderLoginPage();
        attachLoginListeners();
      } else {
        app.innerHTML = renderDashboardLayout();
        attachDashboardListeners();
      }
      try {
        lucide.createIcons();
      } catch(e) {}
      if (AGENTATION_ENABLED) renderAgentationPins();

      // Restore focus and cursor position to the input smoothly
      if (focusedId) {
        const newEl = document.getElementById(focusedId);
        if (newEl && (newEl.tagName === 'INPUT' || newEl.tagName === 'TEXTAREA')) {
          newEl.focus();
          if (selectionStart !== null && selectionEnd !== null) {
            try {
              newEl.setSelectionRange(selectionStart, selectionEnd);
            } catch (_) {}
          }
        }
      }
    }

    // ══════════════════════════════════════════════════════════════════════════
    // 1. LOGIN PAGE
    // ══════════════════════════════════════════════════════════════════════════

    function renderActiveTab() {
      if (state.currentTab === 'overview') return renderOverviewTab();
      if (state.currentTab === 'orders') return renderOrdersTab();
      if (state.currentTab === 'umat') return renderUmatTab();
      if (state.currentTab === 'pengurus') return renderPengurusTab();
      if (state.currentTab === 'romo_paroki') return renderRomoParokiTab();
      if (state.currentTab === 'romo_ordo') return renderRomoOrdoTab();
      if (state.currentTab === 'approvals') return renderApprovalsTab();
      if (state.currentTab === 'master') return renderMasterTab();
      if (state.currentTab === 'chat') return renderChatTab();
      if (state.currentTab === 'qa') return renderQATab();
      if (state.currentTab === 'activity_logs') {
        return typeof isSuperAdminUser === 'function' && isSuperAdminUser() ? renderActivityLogsTab() : renderUnauthorizedTab('Log Aktivitas');
      }
      if (state.currentTab === 'settings') {
        return typeof isSuperAdminUser === 'function' && isSuperAdminUser() ? renderSettingsTab() : renderUnauthorizedTab('Pengaturan Portal');
      }
      return '';
    }

    function renderUnauthorizedTab(menuName) {
      return `
        <div class="p-12 text-center text-slate-500 bg-white rounded-2xl border border-slate-200/90 shadow-sm max-w-lg mx-auto mt-8 space-y-3">
          <div class="w-12 h-12 rounded-full bg-rose-50 text-rose-600 flex items-center justify-center mx-auto border border-rose-100">
            <i data-lucide="shield-alert" class="w-6 h-6"></i>
          </div>
          <h3 class="text-sm font-extrabold text-slate-900">Akses Terbatas: Super Admin Sahaja</h3>
          <p class="text-xs text-slate-500">Menu <b>${menuName}</b> hanya dapat diakses oleh akun peran Super Admin.</p>
          <button onclick="setTab('overview')" class="mt-2 px-4 py-2 bg-blue-950 hover:bg-blue-900 text-white rounded-xl text-xs font-bold transition">Kembali ke Ringkasan</button>
        </div>
      `;
    }

    // ── Tab: Overview ──

function renderModals() {
  return `
    ${typeof renderMasterModal === 'function' ? renderMasterModal() : ''}
    ${typeof renderDeleteConfirmModal === 'function' ? renderDeleteConfirmModal() : ''}
    ${typeof renderActionConfirmModal === 'function' ? renderActionConfirmModal() : ''}
    ${typeof renderEditUserModal === 'function' ? renderEditUserModal() : ''}
    ${typeof renderUserProfileModal === 'function' ? renderUserProfileModal() : ''}
    ${typeof renderOrderDetailModal === 'function' ? renderOrderDetailModal() : ''}
    ${typeof renderChatModal === 'function' ? renderChatModal() : ''}
    ${typeof renderActivityLogDetailModal === 'function' ? renderActivityLogDetailModal() : ''}
    ${typeof renderToastsContainer === 'function' ? renderToastsContainer() : ''}
    ${AGENTATION_ENABLED && typeof renderAgentationPendingDialog === 'function' ? renderAgentationPendingDialog() : ''}
  `;
}

// Initial bootstrap
renderApp();
if (state.currentUser) {
  loadDashboardData();
}
