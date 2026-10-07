// Semua data dari pengguna/API wajib melewati escapeHtml sebelum masuk ke HTML (cegah stored XSS).
function escapeHtml(value) {
  return String(value ?? '').replace(/[&<>"'`]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;', '`': '&#96;' }[c]));
}

// Argumen string untuk atribut handler (onclick="fn(${jsArg(x)})"): literal JS yang aman, lalu di-escape untuk HTML.
function jsArg(value) {
  return escapeHtml(JSON.stringify(String(value ?? '')).replace(/</g, '\\u003c'));
}
