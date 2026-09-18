// ── Log Aktivitas & Audit Trail View & Handlers ──

async function loadActivityLogs(page = 1) {
  state.activityLogsLoading = true;
  state.activityLogsPage = page;
  renderApp();

  try {
    const params = new URLSearchParams();
    params.set('page', String(page));
    params.set('limit', String(state.activityLogsLimit || 20));

    if (state.activityLogsSearch) params.set('search', state.activityLogsSearch.trim());
    if (state.activityLogsFilterRole) params.set('role', state.activityLogsFilterRole);
    if (state.activityLogsFilterAction) params.set('action', state.activityLogsFilterAction);
    if (state.activityLogsFilterEntity) params.set('targetEntity', state.activityLogsFilterEntity);

    const res = await fetch(`${API_BASE}/activity-logs?${params.toString()}`, {
      headers: {
        'Content-Type': 'application/json',
        ...(state.token ? { Authorization: `Bearer ${state.token}` } : {}),
      },
    });

    if (res.ok) {
      const json = await res.json();
      state.activityLogs = json.data || [];
      state.activityLogsTotal = json.meta?.total || 0;
      state.activityLogsTotalPages = json.meta?.totalPages || 1;
    } else {
      showToast('Gagal memuat log aktivitas', 'error');
    }
  } catch (err) {
    console.error('Error loading activity logs:', err);
    showToast('Terjadi kesalahan jaringan saat memuat log aktivitas', 'error');
  } finally {
    state.activityLogsLoading = false;
    renderApp();
  }
}

function getActivityRoleBadge(role) {
  const r = (role || 'SYSTEM').toUpperCase();
  if (r === 'ADMIN') return '<span class="px-2 py-0.5 rounded-full text-[10px] font-extrabold bg-purple-100 text-purple-700 border border-purple-200">ADMIN</span>';
  if (r.startsWith('ROMO')) return '<span class="px-2 py-0.5 rounded-full text-[10px] font-extrabold bg-blue-100 text-blue-700 border border-blue-200">ROMO</span>';
  if (r.includes('PENGURUS')) return '<span class="px-2 py-0.5 rounded-full text-[10px] font-extrabold bg-amber-100 text-amber-700 border border-amber-200">PENGURUS</span>';
  if (r === 'UMAT') return '<span class="px-2 py-0.5 rounded-full text-[10px] font-extrabold bg-emerald-100 text-emerald-700 border border-emerald-200">UMAT</span>';
  return '<span class="px-2 py-0.5 rounded-full text-[10px] font-extrabold bg-slate-100 text-slate-700 border border-slate-200">SYSTEM</span>';
}

function getActionBadge(action) {
  const a = (action || '').toUpperCase();
  let color = 'bg-slate-100 text-slate-700 border-slate-200';
  if (a.includes('LOGIN')) color = 'bg-sky-100 text-sky-800 border-sky-200';
  else if (a.includes('CREATED') || a.includes('BOOT')) color = 'bg-emerald-100 text-emerald-800 border-emerald-200';
  else if (a.includes('APPROVED') || a.includes('CONFIRMED')) color = 'bg-teal-100 text-teal-800 border-teal-200';
  else if (a.includes('REJECTED') || a.includes('FAIL') || a.includes('DELETE')) color = 'bg-rose-100 text-rose-800 border-rose-200';
  else if (a.includes('UPDATE') || a.includes('RESCHEDULE')) color = 'bg-amber-100 text-amber-800 border-amber-200';

  return `<span class="px-2 py-0.5 rounded-md text-[10px] font-bold border font-mono ${color}">${action}</span>`;
}

function formatLogTimestamp(dateStr) {
  if (!dateStr) return '-';
  const d = new Date(dateStr);
  if (isNaN(d.getTime())) return dateStr;
  const time = d.toLocaleTimeString('id-ID', { hour: '2-digit', minute: '2-digit', second: '2-digit' });
  const date = d.toLocaleDateString('id-ID', { day: 'numeric', month: 'short', year: 'numeric' });
  return `<div><span class="font-bold text-slate-800">${time} WIB</span><div class="text-[10px] text-slate-600">${date}</div></div>`;
}

function renderActivityLogsFilter() {
  return `
    <div class="bg-white p-3.5 sm:p-4 rounded-2xl border border-slate-200/80 shadow-xs mb-4">
      <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-3">
        <div>
          <label class="block text-[11px] font-bold text-slate-500 uppercase tracking-wider mb-1">Pencarian</label>
          <input type="text" id="logSearchInput" placeholder="Cari nama, keterangan, ID..."
            value="${state.activityLogsSearch || ''}"
            onchange="state.activityLogsSearch = this.value; loadActivityLogs(1);"
            class="w-full px-3 py-2 text-xs rounded-xl border border-slate-200 bg-slate-50 focus:bg-white focus:outline-hidden focus:ring-2 focus:ring-blue-500 transition" />
        </div>
        <div>
          <label class="block text-[11px] font-bold text-slate-500 uppercase tracking-wider mb-1">Filter Peran</label>
          <select onchange="state.activityLogsFilterRole = this.value; loadActivityLogs(1);"
            class="w-full px-3 py-2 text-xs rounded-xl border border-slate-200 bg-slate-50 focus:bg-white focus:outline-hidden focus:ring-2 focus:ring-blue-500 transition">
            <option value="" ${!state.activityLogsFilterRole ? 'selected' : ''}>Semua Peran</option>
            <option value="ADMIN" ${state.activityLogsFilterRole === 'ADMIN' ? 'selected' : ''}>Admin</option>
            <option value="ROMO" ${state.activityLogsFilterRole === 'ROMO' ? 'selected' : ''}>Romo</option>
            <option value="PENGURUS" ${state.activityLogsFilterRole === 'PENGURUS' ? 'selected' : ''}>Pengurus</option>
            <option value="UMAT" ${state.activityLogsFilterRole === 'UMAT' ? 'selected' : ''}>Umat</option>
            <option value="SYSTEM" ${state.activityLogsFilterRole === 'SYSTEM' ? 'selected' : ''}>System</option>
          </select>
        </div>
        <div>
          <label class="block text-[11px] font-bold text-slate-500 uppercase tracking-wider mb-1">Filter Objek Entitas</label>
          <select onchange="state.activityLogsFilterEntity = this.value; loadActivityLogs(1);"
            class="w-full px-3 py-2 text-xs rounded-xl border border-slate-200 bg-slate-50 focus:bg-white focus:outline-hidden focus:ring-2 focus:ring-blue-500 transition">
            <option value="" ${!state.activityLogsFilterEntity ? 'selected' : ''}>Semua Objek</option>
            <option value="AUTH" ${state.activityLogsFilterEntity === 'AUTH' ? 'selected' : ''}>Autentikasi</option>
            <option value="ORDERS" ${state.activityLogsFilterEntity === 'ORDERS' ? 'selected' : ''}>Pesanan (Orders)</option>
            <option value="AUTH_USERS" ${state.activityLogsFilterEntity === 'AUTH_USERS' ? 'selected' : ''}>Pengguna (Users)</option>
            <option value="SYSTEM" ${state.activityLogsFilterEntity === 'SYSTEM' ? 'selected' : ''}>Sistem Server</option>
          </select>
        </div>
        <div class="flex items-end space-x-2">
          <button onclick="loadActivityLogs(state.activityLogsPage || 1)"
            class="flex-1 py-2 px-3 rounded-xl bg-blue-600 hover:bg-blue-700 text-white font-bold text-xs flex items-center justify-center space-x-1.5 transition shadow-xs">
            <i data-lucide="refresh-cw" class="w-3.5 h-3.5"></i>
            <span>Segarkan</span>
          </button>
          <button onclick="state.activityLogsSearch = ''; state.activityLogsFilterRole = ''; state.activityLogsFilterEntity = ''; loadActivityLogs(1);"
            class="py-2 px-3 rounded-xl bg-slate-100 hover:bg-slate-200 text-slate-600 font-bold text-xs transition" title="Reset Filter">
            <i data-lucide="rotate-ccw" class="w-3.5 h-3.5"></i>
          </button>
        </div>
      </div>
    </div>
  `;
}

function renderActivityLogsTable() {
  if (state.activityLogsLoading) {
    return `
      <div class="bg-white rounded-2xl border border-slate-200 p-12 text-center">
        <div class="inline-block animate-spin w-8 h-8 border-4 border-blue-600 border-t-transparent rounded-full mb-3"></div>
        <p class="text-xs font-bold text-slate-500">Memuat log aktivitas...</p>
      </div>
    `;
  }

  const logs = state.activityLogs || [];
  if (logs.length === 0) {
    return `
      <div class="bg-white rounded-2xl border border-slate-200 p-12 text-center">
        <i data-lucide="scroll-text" class="w-12 h-12 text-slate-300 mx-auto mb-3"></i>
        <h3 class="text-sm font-extrabold text-slate-700">Belum Ada Rekaman Log</h3>
        <p class="text-xs text-slate-600 mt-1">Belum ada aktivitas yang sesuai dengan kriteria filter saat ini.</p>
      </div>
    `;
  }

  return `
    <div class="bg-white rounded-2xl border border-slate-200/80 shadow-xs overflow-hidden">
      <div class="overflow-x-auto">
        <table class="w-full text-left border-collapse text-xs">
          <thead>
            <tr class="bg-slate-50 border-b border-slate-200 text-[11px] font-extrabold text-slate-500 uppercase tracking-wider">
              <th class="p-3.5 whitespace-nowrap">Waktu</th>
              <th class="p-3.5 whitespace-nowrap">Pelaku</th>
              <th class="p-3.5 whitespace-nowrap">Aksi</th>
              <th class="p-3.5 whitespace-nowrap">Objek</th>
              <th class="p-3.5 min-w-[220px]">Deskripsi</th>
              <th class="p-3.5 whitespace-nowrap">IP / Info</th>
              <th class="p-3.5 text-center whitespace-nowrap">Detail</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-slate-100">
            ${logs.map((log) => `
              <tr class="hover:bg-slate-50/80 transition">
                <td class="p-3.5 whitespace-nowrap text-slate-600">${formatLogTimestamp(log.createdAt || log.created_at)}</td>
                <td class="p-3.5 whitespace-nowrap">
                  <div class="font-bold text-slate-800">${log.userName || log.user_name || 'System'}</div>
                  ${getActivityRoleBadge(log.userRole || log.user_role)}
                </td>
                <td class="p-3.5 whitespace-nowrap">${getActionBadge(log.action)}</td>
                <td class="p-3.5 whitespace-nowrap">
                  ${log.targetEntity || log.target_entity ? `<span class="px-1.5 py-0.5 rounded text-[10px] font-bold bg-slate-100 text-slate-700 font-mono">${log.targetEntity || log.target_entity}</span>` : '-'}
                  ${log.targetId || log.target_id ? `<span class="text-[10px] text-blue-700 font-bold ml-1 font-mono">#${log.targetId || log.target_id}</span>` : ''}
                </td>
                <td class="p-3.5 text-slate-700 font-medium">${log.description || '-'}</td>
                <td class="p-3.5 whitespace-nowrap text-slate-600 font-mono text-[10px]">${log.ipAddress || log.ip_address || '-'}</td>
                <td class="p-3.5 text-center whitespace-nowrap">
                  ${(log.metadata && log.metadata !== '{}') ? `
                    <button onclick="openActivityLogDetailModal(${log.id})"
                      class="p-1.5 rounded-lg bg-blue-50 hover:bg-blue-100 text-blue-600 hover:text-blue-700 transition" title="Lihat Payload Metadata">
                      <i data-lucide="eye" class="w-3.5 h-3.5"></i>
                    </button>
                  ` : `<span class="text-slate-500 text-[10px]">-</span>`}
                </td>
              </tr>
            `).join('')}
          </tbody>
        </table>
      </div>
      ${renderActivityLogsPagination()}
    </div>
  `;
}

function renderActivityLogsPagination() {
  const total = state.activityLogsTotal || 0;
  const page = state.activityLogsPage || 1;
  const totalPages = state.activityLogsTotalPages || 1;
  const start = (page - 1) * (state.activityLogsLimit || 20) + 1;
  const end = Math.min(total, page * (state.activityLogsLimit || 20));

  return `
    <div class="p-3.5 sm:p-4 border-t border-slate-100 bg-slate-50 flex flex-col sm:flex-row items-center justify-between gap-3 text-xs text-slate-500 font-medium">
      <div>Menampilkan <strong class="text-slate-800">${total > 0 ? start : 0}</strong> - <strong class="text-slate-800">${end}</strong> dari <strong class="text-slate-800">${total}</strong> rekaman log</div>
      <div class="flex items-center space-x-1.5">
        <button onclick="loadActivityLogs(${page - 1})" ${page <= 1 ? 'disabled' : ''}
          class="px-3 py-1.5 rounded-lg border border-slate-200 bg-white hover:bg-slate-100 text-slate-700 font-bold disabled:opacity-40 disabled:cursor-not-allowed transition">
          Sebelumnya
        </button>
        <span class="px-3 py-1.5 text-slate-700 font-bold">Hal ${page} / ${totalPages}</span>
        <button onclick="loadActivityLogs(${page + 1})" ${page >= totalPages ? 'disabled' : ''}
          class="px-3 py-1.5 rounded-lg border border-slate-200 bg-white hover:bg-slate-100 text-slate-700 font-bold disabled:opacity-40 disabled:cursor-not-allowed transition">
          Berikutnya
        </button>
      </div>
    </div>
  `;
}

function openActivityLogDetailModal(logId) {
  const log = (state.activityLogs || []).find((l) => l.id === logId);
  if (!log) return;
  state.activeLogDetailModal = log;
  renderApp();
}

function closeActivityLogDetailModal() {
  state.activeLogDetailModal = null;
  renderApp();
}

function renderActivityLogDetailModal() {
  const log = state.activeLogDetailModal;
  if (!log) return '';

  let formattedMetadata = '';
  try {
    const parsed = typeof log.metadata === 'string' ? JSON.parse(log.metadata) : log.metadata;
    formattedMetadata = JSON.stringify(parsed, null, 2);
  } catch (_) {
    formattedMetadata = String(log.metadata || '{}');
  }

  return `
    <div class="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-950/60 backdrop-blur-xs">
      <div class="bg-white w-full max-w-lg rounded-2xl shadow-2xl border border-slate-200 overflow-hidden flex flex-col max-h-[85vh]">
        <div class="p-4 border-b border-slate-100 flex items-center justify-between bg-slate-50">
          <div class="flex items-center space-x-2">
            <i data-lucide="scroll-text" class="w-4 h-4 text-blue-600"></i>
            <h3 class="text-sm font-extrabold text-slate-800">Detail Log Audit #${log.id}</h3>
          </div>
          <button onclick="closeActivityLogDetailModal()" class="p-1 rounded-lg text-slate-400 hover:text-slate-600 hover:bg-slate-200 transition">
            <i data-lucide="x" class="w-4 h-4"></i>
          </button>
        </div>
        <div class="p-4 overflow-y-auto space-y-3 custom-scrollbar text-xs">
          <div>
            <span class="text-[10px] font-bold text-slate-400 uppercase tracking-wider">Aksi & Deskripsi</span>
            <div class="mt-1 font-bold text-slate-800">${log.description}</div>
            <div class="mt-1 flex items-center space-x-2">${getActionBadge(log.action)} ${getActivityRoleBadge(log.userRole || log.user_role)}</div>
          </div>
          <div>
            <span class="text-[10px] font-bold text-slate-400 uppercase tracking-wider">Pelaku & IP</span>
            <div class="mt-0.5 text-slate-700 font-medium">${log.userName || log.user_name || 'System'} • IP: <span class="font-mono text-slate-500">${log.ipAddress || log.ip_address || '-'}</span></div>
          </div>
          <div>
            <span class="text-[10px] font-bold text-slate-400 uppercase tracking-wider">User Agent</span>
            <div class="mt-0.5 text-slate-600 font-mono text-[10px] break-all bg-slate-50 p-2 rounded-lg border border-slate-100">${log.userAgent || log.user_agent || '-'}</div>
          </div>
          <div>
            <span class="text-[10px] font-bold text-slate-400 uppercase tracking-wider">Metadata (JSON Payload)</span>
            <pre class="mt-1 p-3 rounded-xl bg-slate-900 text-emerald-400 font-mono text-[11px] overflow-x-auto custom-scrollbar">${formattedMetadata}</pre>
          </div>
        </div>
        <div class="p-3 bg-slate-50 border-t border-slate-100 text-right">
          <button onclick="closeActivityLogDetailModal()" class="px-4 py-1.5 rounded-xl bg-slate-200 hover:bg-slate-300 text-slate-700 font-bold text-xs transition">
            Tutup
          </button>
        </div>
      </div>
    </div>
  `;
}

function renderActivityLogsTab() {
  return `
    <div class="space-y-4">
      <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-2">
        <div>
          <h2 class="text-base sm:text-lg font-extrabold text-slate-900 tracking-tight">Log Aktivitas & Audit Trail</h2>
          <p class="text-xs text-slate-500">Memantau rekaman jejak audit, aktivitas pengguna, dan perubahan status sistem secara real-time.</p>
        </div>
      </div>
      ${renderActivityLogsFilter()}
      ${renderActivityLogsTable()}
    </div>
  `;
}
