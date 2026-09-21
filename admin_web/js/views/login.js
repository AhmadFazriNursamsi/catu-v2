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
          <div class="login-brand mb-4 text-center">
            <img src="assets/logo-catu.png" alt="CATU" class="mx-auto h-9 w-auto object-contain" />
          </div>

          <div class="text-center mb-6">
            <div class="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-[11px] font-bold tracking-wider uppercase bg-blue-50 text-[#165AA7] border border-blue-100/80 mb-2.5 shadow-2xs">
              <span class="w-1.5 h-1.5 rounded-full bg-[#165AA7] animate-pulse"></span>
              <span>Portal Administrator</span>
            </div>
            <h2 class="text-2xl font-extrabold text-[#102D54] tracking-tight">Selamat Datang</h2>
            <p class="text-xs text-slate-500 mt-1">Silakan masuk dengan akun pengurus atau administrator</p>
          </div>

          ${state.loginError ? `
            <div class="mb-5 p-3.5 rounded-xl bg-red-50/90 border border-red-200 text-red-700 text-xs font-semibold flex items-start gap-2.5 animate-fade-in shadow-2xs">
              <i data-lucide="alert-circle" class="w-4 h-4 flex-shrink-0 text-red-600 mt-0.5"></i>
              <span class="flex-1 leading-relaxed">${state.loginError}</span>
            </div>
          ` : ''}

          <form class="form" id="loginForm">
            <div class="field">
              <div class="flex items-center justify-between mb-1.5">
                <label for="username">Nomor WhatsApp / Akun</label>
                <span class="text-[11px] text-slate-400 font-medium">Contoh: 0812...</span>
              </div>
              <div class="field-control">
                <span class="field-icon"><i data-lucide="phone" class="w-4.5 h-4.5"></i></span>
                <input id="username" name="username" type="text" autocomplete="username" placeholder="Masukkan nomor WhatsApp akun Anda" required />
              </div>
            </div>

            <div class="field">
              <div class="flex items-center justify-between mb-1.5">
                <label for="password">Kata Sandi</label>
                <a href="https://wa.me/6285213499965?text=Halo%20Admin%20CATU,%20saya%20butuh%20bantuan%20reset%20kata%20sandi" target="_blank" rel="noopener noreferrer" class="text-[11px] font-semibold text-[#165AA7] hover:underline">Lupa sandi?</a>
              </div>
              <div class="field-control">
                <span class="field-icon"><i data-lucide="lock" class="w-4.5 h-4.5"></i></span>
                <input id="password" name="password" type="password" autocomplete="current-password" placeholder="Masukkan kata sandi Anda" required />
                <button type="button" class="password-toggle" id="togglePassword" aria-label="Tampilkan kata sandi" title="Tampilkan kata sandi">
                  <i data-lucide="eye" class="w-4.5 h-4.5"></i>
                </button>
              </div>
            </div>

            <button type="submit" class="submit-btn" id="submitBtn" ${state.loginLoading ? 'disabled' : ''}>
              ${state.loginLoading ? `
                <span class="flex items-center justify-center space-x-2">
                  <span class="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin"></span>
                  <span>Memverifikasi Kredensial...</span>
                </span>
              ` : `
                <span class="flex items-center justify-center space-x-2">
                  <span>Masuk ke Portal</span>
                  <i data-lucide="arrow-right" class="w-4.5 h-4.5"></i>
                </span>
              `}
            </button>

            <a href="https://wa.me/6285213499965?text=Halo%20Admin%20CATU,%20saya%20butuh%20bantuan%20akses%20akun" target="_blank" rel="noopener noreferrer" class="support group">
              <div class="support-content">
                <div class="support-icon">
                  <i data-lucide="headphones" class="w-4.5 h-4.5"></i>
                </div>
                <div class="support-text">
                  <h4>Butuh bantuan akses?</h4>
                  <p>Hubungi admin CATU via WhatsApp <span class="font-semibold text-[#165AA7] block sm:inline mt-0.5 sm:mt-0">+62 852-1349-9965</span></p>
                </div>
              </div>
              <i data-lucide="chevron-right" class="w-4 h-4 text-slate-400 group-hover:text-[#165AA7] group-hover:translate-x-0.5 transition-all"></i>
            </a>

            <div class="mt-4 pt-3 border-t border-slate-100 flex items-center justify-center gap-1.5 text-[11px] text-slate-400 font-medium">
              <i data-lucide="shield-check" class="w-3.5 h-3.5 text-emerald-600"></i>
              <span>Sistem Terenkripsi & Terlindungi</span>
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
          const isPass = pass.type === 'password';
          pass.type = isPass ? 'text' : 'password';
          toggleBtn.innerHTML = isPass
            ? '<i data-lucide="eye-off" class="w-4.5 h-4.5"></i>'
            : '<i data-lucide="eye" class="w-4.5 h-4.5"></i>';
          toggleBtn.setAttribute('aria-label', isPass ? 'Sembunyikan kata sandi' : 'Tampilkan kata sandi');
          toggleBtn.setAttribute('title', isPass ? 'Sembunyikan kata sandi' : 'Tampilkan kata sandi');
          if (window.lucide && typeof window.lucide.createIcons === 'function') {
            window.lucide.createIcons({ root: toggleBtn });
          }
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
                              data.user && (['ADMIN', 'SUPERADMIN'].includes((data.user.roleCode || data.user.role_code || '').toUpperCase()));

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
