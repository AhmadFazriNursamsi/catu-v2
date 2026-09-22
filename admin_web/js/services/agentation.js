// ── Agentation Visual Feedback System ──
    function renderAgentationToolbar() {
      const pinsCount = state.agentation.annotations.filter(a => !a.resolved).length;
      const isExpanded = state.agentation.expanded;

      return `
        <div data-feedback-toolbar class="fixed bottom-5 right-6 z-[99999] font-sans flex flex-col items-end">
          ${isExpanded ? `
            <div class="mb-3 w-80 bg-slate-900 text-white rounded-2xl p-4 shadow-2xl border border-slate-700 space-y-3.5 backdrop-blur-md bg-opacity-95">
              <div class="flex items-center justify-between border-b border-slate-800 pb-2.5">
                <div class="flex items-center space-x-2">
                  <div class="w-6 h-6 rounded-lg bg-amber-500 text-slate-950 flex items-center justify-center font-black text-xs">🎯</div>
                  <div>
                    <h4 class="text-xs font-extrabold text-white">Agentation Inspector</h4>
                    <p class="text-[10px] text-amber-400">Visual UI Revision Toolbar</p>
                  </div>
                </div>
                <button onclick="state.agentation.expanded = false; renderApp();" class="text-slate-400 hover:text-white p-1">
                  <i data-lucide="x" class="w-4 h-4"></i>
                </button>
              </div>

              <div class="flex items-center justify-between p-2.5 rounded-xl bg-slate-800/80 border border-slate-700">
                <div>
                  <p class="text-xs font-bold text-slate-200">Mode Inspeksi UI</p>
                  <p class="text-[10px] text-slate-400">${state.agentation.enabled ? 'Hover & Klik elemen / popup mana saja' : 'Non-aktif'}</p>
                </div>
                <button onclick="toggleAgentationMode()"
                  class="px-3 py-1.5 rounded-lg text-xs font-black transition ${
                    state.agentation.enabled ? 'bg-amber-500 text-slate-950 shadow-lg' : 'bg-slate-700 text-slate-300 hover:bg-slate-600'
                  }">
                  ${state.agentation.enabled ? 'AKTIF (ON)' : 'MATIKAN (OFF)'}
                </button>
              </div>

              <div class="pt-2 border-t border-slate-800 space-y-2">
                <div class="flex items-center justify-between text-xs font-semibold">
                  <span class="text-slate-400">Total Pin Aktif:</span>
                  <span class="font-bold text-amber-400">${pinsCount} Catatan</span>
                </div>

                <button onclick="copyAgentationPromptToClipboard()"
                  class="w-full py-2 px-3 rounded-xl bg-gradient-to-r from-blue-600 to-indigo-600 hover:from-blue-500 hover:to-indigo-500 text-white font-bold text-xs flex items-center justify-center space-x-2 shadow transition">
                  <i data-lucide="copy" class="w-3.5 h-3.5"></i>
                  <span>📋 Salin Prompt Revisi untuk AI</span>
                </button>
              </div>
            </div>
          ` : ''}

          <button onclick="state.agentation.expanded = !state.agentation.expanded; renderApp();"
            class="toggleContent flex items-center space-x-2.5 px-4 py-3 rounded-full bg-slate-900 hover:bg-slate-800 text-white font-extrabold text-xs shadow-2xl border-2 ${
              state.agentation.enabled ? 'border-amber-400 ring-4 ring-amber-400/30' : 'border-slate-700'
            } transition transform hover:scale-105 active:scale-95">
            <span class="text-base">🎯</span>
            <span>Agentation</span>
            ${pinsCount > 0 ? `<span class="px-2 py-0.5 rounded-full bg-amber-500 text-slate-950 font-black text-[10.5px]">${pinsCount}</span>` : ''}
          </button>
        </div>
      `;
    }

    function renderAgentationPendingDialog() {
      const p = state.agentation.pendingPin;
      if (!p) return '';

      return `
        <div data-agentation-dialog class="fixed inset-0 z-[99999] bg-black/60 backdrop-blur-xs flex items-center justify-center p-4">
          <div class="bg-white rounded-2xl max-w-md w-full p-5 shadow-2xl border border-slate-300 space-y-4 font-sans text-xs">
            <div class="flex items-center justify-between border-b border-slate-200 pb-3">
              <div class="flex items-center space-x-2">
                <span class="w-6 h-6 rounded-lg bg-amber-500 text-slate-950 flex items-center justify-center font-black text-xs">🎯</span>
                <div>
                  <h4 class="font-extrabold text-slate-900 text-sm">Tambah Catatan Revisi UI</h4>
                  <p class="text-[10px] text-slate-500 font-mono truncate max-w-[280px]">${p.selector}</p>
                </div>
              </div>
              <button onclick="state.agentation.pendingPin = null; renderApp();" class="p-1 text-slate-400 hover:bg-slate-100 rounded-lg">
                <i data-lucide="x" class="w-4 h-4"></i>
              </button>
            </div>

            <form onsubmit="saveAgentationPin(event)" class="space-y-3">
              <div class="p-2.5 rounded-xl bg-slate-50 border border-slate-200">
                <p class="text-[10px] font-bold text-slate-500">Elemen Terpilih:</p>
                <p class="font-bold text-blue-950 text-xs mt-0.5">${p.tag.toUpperCase()}: <span class="font-normal text-slate-700">"${(p.text || 'Elemen visual').substring(0, 60)}"</span></p>
              </div>

              <div>
                <label class="block font-bold text-slate-700 mb-1">Tipe / Kategori Revisi:</label>
                <select id="pinCategoryInput" class="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl font-semibold text-slate-900">
                  <option value="BUG">🔴 Bug / Masalah Fungsional / Tampilan Rusak</option>
                  <option value="POLISH">🟡 Desain, Tipografi & Warna</option>
                  <option value="FEATURE">🔵 Tambah / Ubah Fitur & Data</option>
                  <option value="UX">🟢 Alur / UX Flow & Interaksi</option>
                </select>
              </div>

              <div>
                <label class="block font-bold text-slate-700 mb-1">Apa yang perlu diperbaiki / diubah? *</label>
                <textarea id="pinNoteInput" rows="3" required placeholder="Tuliskan revisi detail..."
                  class="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl font-semibold text-slate-900 focus:outline-none focus:ring-2 focus:ring-amber-500 focus:bg-white"></textarea>
              </div>

              <div class="pt-2 flex items-center justify-end space-x-2">
                <button type="button" onclick="state.agentation.pendingPin = null; renderApp();" class="px-4 py-2 rounded-xl bg-slate-100 hover:bg-slate-200 text-slate-700 font-bold">Batal</button>
                <button type="submit" class="px-5 py-2 rounded-xl bg-amber-500 hover:bg-amber-600 text-slate-950 font-black shadow-lg shadow-amber-500/20">
                  ✓ Tambahkan Pin Revisi
                </button>
              </div>
            </form>
          </div>
        </div>
      `;
    }

    function renderAgentationPins() {
      const layer = document.getElementById('agentation-pins-layer');
      if (!layer) return;

      const currentPins = state.agentation.annotations.filter(a => a.pageTab === state.currentTab && !a.resolved);
      layer.innerHTML = currentPins.map((a, idx) => `
        <div class="agentation-pin pointer-events-auto" style="left: ${a.x}px; top: ${a.y}px;"
             onclick="showAgentationPinDetail('${a.id}')"
             title="${a.category}: ${a.note}">
          <div class="w-7 h-7 rounded-full bg-red-600 text-white font-black text-xs flex items-center justify-center shadow-2xl border-2 border-white ring-2 ring-black/20">
            ${idx + 1}
          </div>
        </div>
      `).join('');
    }

    function toggleAgentationMode() {
      state.agentation.enabled = !state.agentation.enabled;
      if (state.agentation.enabled) state.agentation.expanded = true;
      renderApp();
    }

    function saveAgentationPin(e) {
      e.preventDefault();
      const p = state.agentation.pendingPin;
      if (!p) return;

      const note = document.getElementById('pinNoteInput').value.trim();
      const category = document.getElementById('pinCategoryInput').value;

      state.agentation.annotations.push({
        id: 'pin_' + Date.now(),
        x: p.x,
        y: p.y,
        pageTab: state.currentTab,
        elementSelector: p.selector,
        elementTag: p.tag,
        elementText: p.text,
        category,
        note,
        createdAt: new Date().toISOString(),
        resolved: false,
      });

      localStorage.setItem('catu_agentation_annotations', JSON.stringify(state.agentation.annotations));
      state.agentation.pendingPin = null;
      renderApp();
    }

    function copyAgentationPromptToClipboard() {
      const list = state.agentation.annotations.filter(a => !a.resolved);
      if (list.length === 0) {
        showToast('Belum ada catatan revisi Agentation yang ditambahkan.', 'warning', 'Catatan Kosong');
        return;
      }

      let prompt = `### 🎯 DAFTAR REVISI UI / DESAIN AGENTATION (${state.currentTab.toUpperCase()}):\n\n`;
      list.forEach((a, i) => {
        prompt += `${i + 1}. [${a.category}] Elemen: \`${a.elementSelector}\`\n   - Catatan: "${a.note}"\n   - Tag: <${a.elementTag}>\n\n`;
      });
      prompt += `Tolong revisi dan perbaiki elemen-elemen UI di atas sesuai catatan tepat sasaran.`;

      navigator.clipboard.writeText(prompt).then(() => {
        state.agentation.annotations = [];
        localStorage.setItem('catu_agentation_annotations', JSON.stringify([]));
        state.agentation.enabled = false;
        state.agentation.expanded = false;
        
        const box = document.getElementById('agentation-inspector-box');
        if (box) box.style.display = 'none';

        renderApp();
        showToast('Seluruh catatan revisi Agentation berhasil disalin ke clipboard & pin dibersihkan! Silakan Paste prompt ke chat AI.', 'success', 'Tersalin ke Clipboard! 📋');
      }).catch(() => {
        state.agentation.annotations = [];
        localStorage.setItem('catu_agentation_annotations', JSON.stringify([]));
        renderApp();
        showToast('Pin revisi telah dibersihkan.', 'info', 'Pin Dibersihkan');
      });
    }

    // ── Mouse Listeners for Agentation (Popup-Compatible) ──
    window.addEventListener('mousemove', (e) => {
      if (!state.agentation.enabled) {
        const box = document.getElementById('agentation-inspector-box');
        if (box) box.style.display = 'none';
        return;
      }

      const target = document.elementFromPoint(e.clientX, e.clientY);
      if (!target || target.closest('[data-feedback-toolbar]') || target.closest('.agentation-pin') || target.closest('[data-agentation-dialog]') || target.id === 'agentation-inspector-box') {
        return;
      }

      const rect = target.getBoundingClientRect();
      const box = document.getElementById('agentation-inspector-box');
      const label = document.getElementById('agentation-inspector-label');
      if (box && label) {
        box.style.display = 'block';
        box.style.left = `${rect.left}px`;
        box.style.top = `${rect.top}px`;
        box.style.width = `${rect.width}px`;
        box.style.height = `${rect.height}px`;

        const tag = target.tagName.toLowerCase();
        const idStr = target.id ? ('#' + target.id) : '';
        const cls = target.className && typeof target.className === 'string' ? ('.' + target.className.trim().split(' ')[0]) : '';
        label.textContent = `${tag}${idStr || cls} (${Math.round(rect.width)}x${Math.round(rect.height)})`;
      }
    });

    window.addEventListener('click', (e) => {
      if (!state.agentation.enabled) return;

      const target = document.elementFromPoint(e.clientX, e.clientY);
      if (!target || target.closest('[data-feedback-toolbar]') || target.closest('.agentation-pin') || target.closest('[data-agentation-dialog]') || target.id === 'agentation-inspector-box') {
        return;
      }

      e.preventDefault();
      e.stopPropagation();

      const modalParent = target.closest('.fixed:not([data-agentation-dialog]):not(aside)');
      let modalPrefix = '';
      if (modalParent) {
        const modalTitle = modalParent.querySelector('h3, h4')?.innerText?.trim() || 'Popup Modal';
        modalPrefix = `[Popup: ${modalTitle}] > `;
      }

      let path = [];
      let el = target;
      while (el && el.nodeType === Node.ELEMENT_NODE && path.length < 4) {
        if (el === modalParent) break;
        let sel = el.nodeName.toLowerCase();
        if (el.id) {
          sel += '#' + el.id;
          path.unshift(sel);
          break;
        } else {
          let sib = el, nth = 1;
          while (sib = sib.previousElementSibling) {
            if (sib.nodeName.toLowerCase() == sel) nth++;
          }
          if (nth != 1) sel += ":nth-of-type("+nth+")";
        }
        path.unshift(sel);
        el = el.parentNode;
      }

      const fullSelector = modalPrefix + (path.join(' > ') || target.tagName.toLowerCase());

      state.agentation.pendingPin = {
        x: e.clientX,
        y: e.clientY,
        selector: fullSelector,
        tag: target.tagName.toLowerCase(),
        text: (target.value || target.placeholder || target.innerText || target.textContent || '').trim().substring(0, 100),
      };

      const box = document.getElementById('agentation-inspector-box');
      if (box) box.style.display = 'none';

      renderApp();
    }, true);

    // ══════════════════════════════════════════════════════════════════════════
    // SEARCHABLE COMBOBOX COMPONENT (SEARCH INSIDE DROPDOWN PANEL)
    // ══════════════════════════════════════════════════════════════════════════
