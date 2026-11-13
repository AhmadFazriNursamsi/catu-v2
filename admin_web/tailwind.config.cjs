/** CSS Tailwind disusun saat build (bukan di browser lewat cdn.tailwindcss.com). */
module.exports = {
  content: ['./index.html', './js/**/*.js'],
  // Kelas yang dirakit dinamis (`bg-${color}-600` di approval-helpers.js) tidak terbaca pemindai.
  safelist: [{ pattern: /^(bg|shadow)-(emerald|rose)-(600|700)(\/20)?$/, variants: ['hover'] }],
  theme: { extend: {} },
  plugins: [],
};
