// ── Masa jabatan (Pengurus, Koordinator, Kepala Romo Paroki, Ketua Romo Ordo) di form Edit Pengguna ──
// Disimpan sebagai tanggal dd/mm/yyyy (jabatan_start_date / jabatan_end_date, format yang sama dengan pendaftaran
// di aplikasi). Kolom tahun tetap diisi dari tanggal agar tampilan dan aturan lama yang memakai tahun tetap benar.

// 'dd/mm/yyyy' (atau tahun saja untuk data lama) -> 'yyyy-mm-dd' untuk <input type="date">.
function jabatanToIso(dmy, year, isEnd) {
  const m = String(dmy || '').match(/^(\d{2})\/(\d{2})\/(\d{4})$/);
  if (m) return `${m[3]}-${m[2]}-${m[1]}`;
  const y = parseInt(year);
  return y ? `${y}-${isEnd ? '12-31' : '01-01'}` : '';
}

function jabatanIsoToDmy(iso) {
  const m = String(iso || '').match(/^(\d{4})-(\d{2})-(\d{2})$/);
  return m ? `${m[3]}/${m[2]}/${m[1]}` : null;
}

// Teks periode jabatan dd/mm/yyyy (data lama yang hanya punya tahun tetap tampil tahun).
function jabatanPeriodText(u) {
  const fmt = (dmy, year) => (/^\d{2}\/\d{2}\/\d{4}$/.test(String(dmy || '')) ? dmy : (year ? String(year) : ''));
  const start = fmt(u.jabatan_start_date || u.jabatanStartDate, u.jabatan_start_year || u.jabatanStartYear);
  const end = fmt(u.jabatan_end_date || u.jabatanEndDate, u.jabatan_end_year || u.jabatanEndYear);
  return start && end ? `${start} - ${end}` : (start ? `${start} - Sekarang` : 'Aktif');
}

function jabatanDateInputs(u) {
  const cls = 'w-full px-3.5 py-2.5 bg-white border border-slate-200 rounded-xl font-bold text-slate-900 text-xs focus:outline-none focus:ring-2 focus:ring-blue-500 shadow-xs';
  const start = jabatanToIso(u.jabatan_start_date || u.jabatanStartDate, u.jabatan_start_year || u.jabatanStartYear, false);
  const end = jabatanToIso(u.jabatan_end_date || u.jabatanEndDate, u.jabatan_end_year || u.jabatanEndYear, true);
  return `
                      <div>
                        <label class="block font-extrabold text-slate-700 mb-1.5">Tanggal Mulai</label>
                        <input type="date" id="editJabatanStartDate" value="${escapeHtml(start)}" class="${cls}" />
                      </div>
                      <div>
                        <label class="block font-extrabold text-slate-700 mb-1.5">Tanggal Selesai</label>
                        <input type="date" id="editJabatanEndDate" value="${escapeHtml(end)}" class="${cls}" />
                      </div>`;
}

// Isi payload dari input tanggal. Mengembalikan pesan galat atau null.
function readJabatanDates(payload) {
  const s = document.getElementById('editJabatanStartDate');
  const e = document.getElementById('editJabatanEndDate');
  if (!s && !e) return null;
  const sIso = s ? s.value : '';
  const eIso = e ? e.value : '';
  if (sIso && eIso && eIso < sIso) return 'Tanggal selesai jabatan tidak boleh sebelum tanggal mulai.';
  payload.jabatanStartDate = jabatanIsoToDmy(sIso);
  payload.jabatanEndDate = jabatanIsoToDmy(eIso);
  payload.jabatanStartYear = sIso ? parseInt(sIso.slice(0, 4)) : null;
  payload.jabatanEndYear = eIso ? parseInt(eIso.slice(0, 4)) : null;
  const today = new Date().toISOString().slice(0, 10);
  payload.isJabatanActive = eIso ? eIso >= today : true;
  return null;
}

function clearJabatan(payload) {
  payload.jabatanStartYear = null;
  payload.jabatanEndYear = null;
  payload.jabatanStartDate = null;
  payload.jabatanEndDate = null;
  payload.isJabatanActive = false;
}

// Simpan isian tanggal ke state saat form dirender ulang (mis. ganti dropdown).
function syncJabatanDatesToState(u) {
  const s = document.getElementById('editJabatanStartDate');
  if (s) { u.jabatan_start_date = jabatanIsoToDmy(s.value); u.jabatan_start_year = s.value ? parseInt(s.value.slice(0, 4)) : null; }
  const e = document.getElementById('editJabatanEndDate');
  if (e) { u.jabatan_end_date = jabatanIsoToDmy(e.value); u.jabatan_end_year = e.value ? parseInt(e.value.slice(0, 4)) : null; }
}
