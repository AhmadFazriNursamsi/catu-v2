// ── Admin Login View & Handlers ──
    function renderLoginHero() {
      return `
        <section class="hero">
          <div class="hero-content">
            <div class="brand">
              <img src="assets/logo-catu-light.png" alt="CATU — Cari & Bantu" />
            </div>

            <div class="hero-main">
              <div class="eyebrow">PORTAL ADMINISTRASI</div>
              <h1>
                Pelayanan Gereja
                <span>dalam Satu Sistem</span>
              </h1>
              <p class="hero-description">
                Kelola data umat, administrasi paroki, dan berbagai layanan gereja secara mudah, aman, dan terintegrasi.
              </p>

              <div class="features">
                <div class="feature">
                  <div class="feature-icon"><i data-lucide="users" class="w-5 h-5"></i></div>
                  <div class="feature-body">
                    <h3>Data Umat Terpadu</h3>
                    <p>Informasi umat lebih rapi dan akurat.</p>
                  </div>
                </div>
                <div class="feature">
                  <div class="feature-icon"><i data-lucide="file-text" class="w-5 h-5"></i></div>
                  <div class="feature-body">
                    <h3>Administrasi Paroki</h3>
                    <p>Kelola kegiatan dan layanan dengan efisien.</p>
                  </div>
                </div>
                <div class="feature">
                  <div class="feature-icon"><i data-lucide="shield-check" class="w-5 h-5"></i></div>
                  <div class="feature-body">
                    <h3>Aman & Terpercaya</h3>
                    <p>Data Anda kami jaga dengan baik.</p>
                  </div>
                </div>
              </div>
            </div>

            <div class="hero-footer">
              <div class="location">
                <span class="location-dot">●</span>
                <span>Gereja Katedral Jakarta</span>
              </div>
              <div class="tagline">BERSAMA DALAM IMAN, MELAYANI DENGAN KASIH</div>
            </div>
          </div>
        </section>
      `;
    }

    function renderLoginCard(state) {
      return `
        <div class="login-card">
          <div class="login-brand">
            <img src="assets/logo-catu.png" alt="CATU" />
          </div>
          <h2 class="login-title">Masuk Portal Admin</h2>
          <p class="login-subtitle">
            Masukkan kredensial administrator untuk mengakses dashboard.
          </p>

          ${state.loginError ? `
            <div class="mb-4 p-3.5 rounded-xl bg-red-50 border border-red-200 text-red-700 text-xs font-semibold flex items-start space-x-2.5">
              <i data-lucide="alert-circle" class="w-4 h-4 flex-shrink-0 text-red-600 mt-0.5"></i>
              <span>${state.loginError}</span>
            </div>
          ` : ''}

          <form class="form" id="loginForm">
            <div class="field">
              <label for="username">Nomor WhatsApp / Akun</label>
              <div class="field-control">
                <span class="field-icon"><i data-lucide="phone" class="w-5 h-5"></i></span>
                <input id="username" name="username" type="text" autocomplete="username" placeholder="Masukkan nomor WhatsApp akun Anda" required />
              </div>
            </div>

            <div class="field">
              <label for="password">Kata sandi</label>
              <div class="field-control">
                <span class="field-icon"><i data-lucide="lock" class="w-5 h-5"></i></span>
                <input id="password" name="password" type="password" autocomplete="current-password" placeholder="Masukkan kata sandi Anda" required />
                <button type="button" class="password-toggle" id="togglePassword" aria-label="Tampilkan kata sandi">
                  <i data-lucide="eye" class="w-5 h-5"></i>
                </button>
              </div>
            </div>

            <div class="form-options">
              <label class="remember">
                <input type="checkbox" name="remember" id="rememberMe" />
                <span>Ingat saya</span>
              </label>
              <a href="javascript:void(0)" onclick="alert('Silakan hubungi administrator paroki untuk bantuan reset kata sandi.')" class="forgot">
                Lupa kata sandi?
              </a>
            </div>

            <button type="submit" class="submit-btn" id="submitBtn" ${state.loginLoading ? 'disabled' : ''}>
              ${state.loginLoading ? `
                <span class="flex items-center space-x-2">
                  <span class="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin"></span>
                  <span>Memverifikasi...</span>
                </span>
                <span></span>
              ` : `
                <span>Masuk</span>
                <span class="arrow"><i data-lucide="arrow-right" class="w-5 h-5"></i></span>
              `}
            </button>

            <div class="support" onclick="alert('Hubungi tim administrator CATU di nomor WhatsApp paroki untuk bantuan.')">
              <div class="support-content">
                <div class="support-icon">
                  <i data-lucide="headphones" class="w-5 h-5"></i>
                </div>
                <div class="support-text">
                  <h4>Butuh bantuan?</h4>
                  <p>Hubungi tim operasional atau administrator CATU untuk bantuan akses akun.</p>
                </div>
              </div>
              <i data-lucide="arrow-right" class="w-4 h-4 text-slate-400"></i>
            </div>
          </form>
        </div>
      `;
    }

    function renderLoginPage() {
      return `
        <main class="login-page">
          ${renderLoginHero()}

          <section class="login-side">
            ${renderLoginCard(state)}

            <div class="side-footer">
              <i data-lucide="shield" class="w-5 h-5 text-[#165AA7]"></i>
              <div>
                <div class="font-medium text-slate-600">Sistem Administrasi Pastoral</div>
                <div class="text-slate-400 text-[10.5px]">Keuskupan Agung Jakarta</div>
              </div>
            </div>
          </section>
        </main>
      `;
    }

    function attachLoginListeners() {
      const toggleBtn = document.getElementById('togglePassword') || document.getElementById('togglePasswordBtn');
      const pass = document.getElementById('password') || document.getElementById('passwordInput');
      if (toggleBtn && pass) {
        toggleBtn.addEventListener('click', () => {
          pass.type = pass.type === 'password' ? 'text' : 'password';
        });
      }

      const form = document.getElementById('loginForm');
      if (form) {
        form.addEventListener('submit', async (e) => {
          e.preventDefault();
          const phoneInput = document.getElementById('username') || document.getElementById('phoneInput');
          const passInput = document.getElementById('password') || document.getElementById('passwordInput');
          let phone = phoneInput ? phoneInput.value.trim() : '';
          const password = passInput ? passInput.value.trim() : '';

          // Normalize phone: strip non-digits, remove leading '62' or '0'
          phone = phone.replace(/[^0-9]/g, '');
          if (phone.startsWith('62')) {
            phone = phone.substring(2);
          } else if (phone.startsWith('0')) {
            phone = phone.substring(1);
          }

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
