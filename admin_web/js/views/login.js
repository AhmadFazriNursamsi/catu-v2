// ── Admin Login View & Handlers ──
    function renderLoginPage() {
      return `
        <div class="min-h-full flex flex-col lg:flex-row">
          <div class="church-bg lg:w-[54%] p-8 lg:p-14 flex flex-col justify-between text-white relative">
            <div>
              <div class="flex items-center justify-between">
                <div class="flex items-center space-x-3.5">
                  <div class="w-12 h-12 rounded-xl bg-white p-1.5 shadow-lg border-2 border-amber-500 flex items-center justify-center flex-shrink-0">
                    <img src="assets/images/logoCatu.png" alt="CATU Logo" class="h-full object-contain" />
                  </div>
                  <div>
                    <h1 class="text-xl font-extrabold tracking-wider text-white">CATU WEB PORTAL</h1>
                    <p class="text-[11px] font-bold text-amber-400 tracking-wider">CARI & BANTU PELAYANAN GEREJA</p>
                  </div>
                </div>
                <div class="hidden sm:inline-flex items-center px-3 py-1 rounded-full bg-white/10 border border-white/20 text-xs font-semibold text-white/90">
                  <i data-lucide="shield-alert" class="w-3.5 h-3.5 mr-1.5 text-amber-400"></i>
                  Portal Khusus Administrator
                </div>
              </div>
            </div>

            <div class="my-12 lg:my-0 max-w-xl">
              <h2 class="text-3xl lg:text-4xl font-extrabold leading-tight tracking-tight text-white mb-4">
                Sistem Informasi & Manajemen<br/><span class="text-amber-400">Pelayanan Umat Katolik</span>
              </h2>
              <p class="text-slate-300 text-sm lg:text-base leading-relaxed mb-8">
                Platform terpusat untuk monitoring pelayanan Misa Kedukaan, Sakramen Perminyakan, verifikasi pendaftaran berjenjang, dan koordinasi lintas paroki.
              </p>

              <div class="space-y-4">
                <div class="flex items-start space-x-3.5 p-3.5 rounded-xl bg-white/5 border border-white/10 backdrop-blur-sm">
                  <div class="p-2 rounded-lg bg-amber-500/20 text-amber-400">
                    <i data-lucide="church" class="w-5 h-5"></i>
                  </div>
                  <div>
                    <h3 class="text-sm font-bold text-white">Integrasi Lintas Paroki & Ordo</h3>
                    <p class="text-xs text-slate-300">Pengelolaan permohonan pelayanan sakramental secara transparan dan terstruktur.</p>
                  </div>
                </div>

                <div class="flex items-start space-x-3.5 p-3.5 rounded-xl bg-white/5 border border-white/10 backdrop-blur-sm">
                  <div class="p-2 rounded-lg bg-emerald-500/20 text-emerald-400">
                    <i data-lucide="user-check" class="w-5 h-5"></i>
                  </div>
                  <div>
                    <h3 class="text-sm font-bold text-white">Persetujuan Akun Berjenjang</h3>
                    <p class="text-xs text-slate-300">Verifikasi pendaftaran Umat, Romo, dan Pengurus Lingkungan dengan satu klik.</p>
                  </div>
                </div>
              </div>
            </div>

            <div class="flex items-center text-xs text-slate-400 space-x-2 pt-6 border-t border-white/10">
              <i data-lucide="shield-check" class="w-4 h-4 text-emerald-400"></i>
              <span>CATU Platform v2.5.0 • Powered by NestJS & PostgreSQL 16</span>
            </div>
          </div>

          <div class="cross-bg lg:w-[46%] p-8 lg:p-14 flex items-center justify-center">
            <div class="w-full max-w-md bg-white rounded-3xl p-8 lg:p-10 shadow-2xl border border-slate-200">
              <div class="text-center mb-8">
                <img src="assets/images/logoCatu.png" alt="CATU Logo" class="h-16 mx-auto mb-4 object-contain" />
                <h2 class="text-2xl font-extrabold text-slate-900 tracking-tight">Masuk Portal Admin</h2>
                <p class="text-xs text-slate-500 mt-1">Masukkan kredensial Administrator untuk mengakses dashboard.</p>
              </div>

              ${state.loginError ? `
                <div class="mb-6 p-4 rounded-xl bg-red-50 border border-red-200 text-red-700 text-xs font-semibold flex items-start space-x-2.5">
                  <i data-lucide="alert-circle" class="w-5 h-5 flex-shrink-0 text-red-600"></i>
                  <span>${state.loginError}</span>
                </div>
              ` : ''}

              <form id="loginForm" class="space-y-4">
                <div>
                  <label class="block text-xs font-bold text-slate-700 mb-1.5">Nomor WhatsApp</label>
                  <div class="relative rounded-xl shadow-sm">
                    <div class="absolute inset-y-0 left-0 pl-3.5 flex items-center pointer-events-none">
                      <span class="text-xs font-bold text-slate-700 border-r border-slate-300 pr-2">+62</span>
                    </div>
                    <input type="tel" id="phoneInput" required placeholder="81234567890" autocomplete="username" inputmode="numeric" aria-describedby="phoneHint"
                      class="block w-full pl-14 pr-4 py-3 bg-slate-50 border border-slate-200 rounded-xl text-sm font-semibold text-slate-900 placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-amber-500 focus:bg-white" />
                  </div>
                  <p id="phoneHint" class="mt-1.5 text-[11px] font-medium text-slate-400">Masukkan nomor tanpa 0 di depan atau tanda +62.</p>
                </div>

                <div>
                  <label class="block text-xs font-bold text-slate-700 mb-1.5">Kata Sandi</label>
                  <div class="relative rounded-xl shadow-sm">
                    <div class="absolute inset-y-0 left-0 pl-3.5 flex items-center pointer-events-none text-slate-400">
                      <i data-lucide="lock" class="w-4 h-4 text-blue-900"></i>
                    </div>
                    <input type="password" id="passwordInput" required placeholder="Masukkan kata sandi" autocomplete="current-password"
                      class="block w-full pl-10 pr-10 py-3 bg-slate-50 border border-slate-200 rounded-xl text-sm font-semibold text-slate-900 placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-blue-900 focus:bg-white" />
                    <button type="button" id="togglePasswordBtn" class="absolute inset-y-0 right-0 pr-3.5 flex items-center text-slate-400 hover:text-slate-600">
                      <i data-lucide="eye" class="w-4 h-4"></i>
                    </button>
                  </div>
                </div>

                <div class="pt-2">
                  <button type="submit" id="submitBtn" ${state.loginLoading ? 'disabled' : ''}
                    class="w-full py-3.5 px-4 bg-blue-950 hover:bg-blue-900 text-white text-sm font-bold rounded-xl shadow-lg shadow-blue-950/20 flex items-center justify-center space-x-2 transition duration-200 disabled:opacity-50">
                    ${state.loginLoading ? `
                      <span class="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin"></span>
                      <span>Memverifikasi...</span>
                    ` : `
                      <i data-lucide="log-in" class="w-4 h-4"></i>
                      <span>MASUK KE PORTAL ADMIN</span>
                    `}
                  </button>
                </div>
              </form>
            </div>
          </div>
        </div>
      `;
    }

    function attachLoginListeners() {
      const toggleBtn = document.getElementById('togglePasswordBtn');
      if (toggleBtn) {
        toggleBtn.addEventListener('click', () => {
          const pass = document.getElementById('passwordInput');
          pass.type = pass.type === 'password' ? 'text' : 'password';
        });
      }

      const form = document.getElementById('loginForm');
      if (form) {
        form.addEventListener('submit', async (e) => {
          e.preventDefault();
          const phone = document.getElementById('phoneInput').value.trim();
          const password = document.getElementById('passwordInput').value.trim();

          state.loginLoading = true;
          state.loginError = '';
          renderApp();

          try {
            const res = await fetch(`${API_BASE}/auth/admin/login`, {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({ phoneNumber: phone, password }),
            });
            const data = await res.json();

            const isSuccess = (res.ok || res.status === 200 || data.statusCode === 200) &&
                              data.user && (data.user.roleCode === 'ADMIN' || data.user.role_code === 'ADMIN');

            if (isSuccess) {
              state.currentUser = data.user;
              state.token = data.accessToken || '';
              localStorage.setItem('catu_admin_user', JSON.stringify(data.user));
              localStorage.setItem('catu_admin_token', data.accessToken || '');
              state.loginLoading = false;
              state.loginError = '';
              renderApp();
              loadDashboardData();
            } else {
              state.loginError = data.message || 'Login gagal. Pastikan Anda menggunakan akun Administrator.';
              state.loginLoading = false;
              renderApp();
            }
          } catch (err) {
            state.loginError = `Gagal menghubungi server backend (${API_BASE}).`;
            state.loginLoading = false;
            renderApp();
          }
        });
      }
    }

    // ══════════════════════════════════════════════════════════════════════════
    // 2. DASHBOARD MAIN LAYOUT & SIDEBAR
    // ══════════════════════════════════════════════════════════════════════════
