// Penanda lingkungan non-produksi (mis. DEV) agar tidak tertukar dengan produksi. Kosong di produksi.
(function () {
  const name = (window.CATU_RUNTIME_CONFIG?.envName || '').trim();
  if (!name) return;
  document.title = `[${name}] ${document.title}`;
  const mount = () => {
    const bar = document.createElement('div');
    bar.textContent = `LINGKUNGAN ${name.toUpperCase()} - data uji, bukan produksi`;
    bar.setAttribute('style', 'position:fixed;top:0;left:0;right:0;z-index:2147483647;background:#b91c1c;color:#fff;font:700 11px/22px system-ui,sans-serif;text-align:center;letter-spacing:.04em;pointer-events:none');
    document.body.appendChild(bar);
    document.body.style.paddingTop = '22px';
  };
  if (document.body) mount(); else document.addEventListener('DOMContentLoaded', mount);
})();
