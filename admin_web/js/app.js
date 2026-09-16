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
      if (!state.currentUser || (state.currentUser.roleCode !== 'ADMIN' && state.currentUser.role_code !== 'ADMIN')) {
        app.innerHTML = renderLoginPage();
        attachLoginListeners();
      } else {
        app.innerHTML = renderDashboardLayout();
        attachDashboardListeners();
      }
      try {
        lucide.createIcons();
      } catch(e) {}
      renderAgentationPins();

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
      return '';
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
    ${typeof renderToastsContainer === 'function' ? renderToastsContainer() : ''}
    ${typeof renderAgentationPendingDialog === 'function' ? renderAgentationPendingDialog() : ''}
  `;
}

// Initial bootstrap
renderApp();
if (state.currentUser) {
  loadDashboardData();
}
