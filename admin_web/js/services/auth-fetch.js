// ── Auth-aware fetch ──
// Melampirkan token admin ke setiap request ke API CATU dan mengakhiri sesi bila server menjawab 401.
(function installAuthFetch() {
  const originalFetch = window.fetch.bind(window);
  const PUBLIC_PATHS = ['/auth/admin/login', '/health'];

  function isApiRequest(url) {
    return typeof url === 'string' && url.startsWith(API_BASE);
  }

  function isPublicPath(url) {
    const path = url.split('?')[0];
    return PUBLIC_PATHS.some((p) => path.endsWith(p));
  }

  function endSession() {
    if (!state.token) return;
    localStorage.removeItem('catu_admin_user');
    localStorage.removeItem('catu_admin_token');
    state.currentUser = null;
    state.token = '';
    if (typeof showToast === 'function') {
      showToast('Sesi Anda telah berakhir. Silakan masuk kembali.', 'error', 'Sesi Berakhir');
    }
    if (typeof renderApp === 'function') renderApp();
  }

  window.fetch = async function authFetch(input, init) {
    const url = typeof input === 'string' ? input : input?.url;
    if (!isApiRequest(url) || isPublicPath(url)) return originalFetch(input, init);

    const headers = new Headers(init?.headers || (typeof input === 'string' ? undefined : input.headers));
    if (state.token && !headers.has('Authorization')) {
      headers.set('Authorization', `Bearer ${state.token}`);
    }
    const response = await originalFetch(input, { ...init, headers });
    if (response.status === 401 && state.token) endSession();
    return response;
  };
})();
