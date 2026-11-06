/** Tanggal berlaku kebijakan; ubah bersama isinya. */
export const PRIVACY_EFFECTIVE_DATE = '6 November 2026';

export interface PrivacyContact {
  /** Nama pengelola aplikasi (PRIVACY_CONTROLLER_NAME). */
  controllerName?: string;
  /** Email kontak privasi (PRIVACY_CONTACT_EMAIL). */
  contactEmail?: string;
}

const EMAIL_PATTERN = /^[^\s@<>"']+@[^\s@<>"']+\.[^\s@<>"']+$/;

function escapeHtml(value: string): string {
  return value.replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c] as string);
}

/** Kebijakan privasi publik CATU (dibutuhkan App Store / Play Store). Isinya mengikuti data yang benar-benar diproses kode. */
export function renderPrivacyPage(contact: PrivacyContact): string {
  const name = contact.controllerName?.trim() ? escapeHtml(contact.controllerName.trim()) : 'pengelola aplikasi CATU';
  const email = contact.contactEmail?.trim() ?? '';
  const reach = EMAIL_PATTERN.test(email)
    ? `email <a href="mailto:${escapeHtml(email)}">${escapeHtml(email)}</a>`
    : 'menu <b>Pusat Bantuan</b> di aplikasi';
  return `<!doctype html>
<html lang="id"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Kebijakan Privasi CATU</title>
<style>body{font-family:system-ui,sans-serif;background:#f8fafc;color:#0f172a;margin:0;padding:24px 16px;line-height:1.6}
main{max-width:760px;margin:0 auto;background:#fff;border:1px solid #e2e8f0;border-radius:16px;padding:28px 24px}
h1{font-size:24px;margin:0 0 4px}h2{font-size:17px;margin:28px 0 8px}p,li{font-size:15px;color:#334155}
.meta{color:#64748b;font-size:13px;margin:0 0 20px}a{color:#0066ff}ul{padding-left:20px}</style></head>
<body><main>
<h1>Kebijakan Privasi CATU</h1>
<p class="meta">Berlaku sejak ${PRIVACY_EFFECTIVE_DATE}</p>
<p>CATU adalah aplikasi untuk mengajukan dan mengatur pelayanan sakramen dan pastoral antara umat, pengurus lingkungan,
paroki, dan Romo. Aplikasi ini dikelola oleh ${name}. Kebijakan ini menjelaskan data apa yang kami kumpulkan, untuk apa,
siapa yang dapat melihatnya, dan bagaimana Anda dapat menghapusnya.</p>

<h2>1. Data yang kami kumpulkan</h2>
<ul>
<li><b>Akun:</b> nomor HP, kata sandi (disimpan dalam bentuk hash, tidak dapat dibaca), peran, dan status persetujuan.</li>
<li><b>Profil:</b> nama, email, tanggal lahir, jenis kelamin, alamat, foto profil, serta keuskupan, paroki, wilayah,
dan lingkungan. Untuk Romo dan pengurus: jabatan, masa jabatan, dan ordo.</li>
<li><b>Pelayanan:</b> jenis pelayanan, jadwal, lokasi, catatan, lampiran, riwayat perubahan jadwal, dan ulasan.</li>
<li><b>Chat:</b> pesan dan lampiran di grup chat setiap pelayanan.</li>
<li><b>Perangkat:</b> token notifikasi, jenis dan model perangkat.</li>
<li><b>Catatan teknis:</b> alamat IP, jenis aplikasi/peramban, dan catatan aktivitas untuk keamanan dan penelusuran masalah.</li>
</ul>
<p>Aplikasi meminta akses kamera dan galeri hanya saat Anda memilih foto profil atau lampiran. Kami tidak mengumpulkan
lokasi GPS, kontak, atau data dari aplikasi lain, tidak menampilkan iklan, dan tidak melacak Anda di aplikasi atau situs lain.</p>

<h2>2. Untuk apa data dipakai</h2>
<ul>
<li>Membuat dan mengamankan akun Anda, termasuk verifikasi keanggotaan oleh pengurus lingkungan.</li>
<li>Meneruskan permohonan pelayanan ke Romo dan pengurus yang berwenang, serta mengatur jadwalnya.</li>
<li>Mengirim notifikasi dan pesan terkait pelayanan, kode verifikasi, dan tautan masuk.</li>
<li>Menjaga keamanan layanan dan memperbaiki masalah.</li>
</ul>
<p>Kami tidak menjual data Anda dan tidak memakainya untuk iklan.</p>

<h2>3. Siapa yang dapat melihat data Anda</h2>
<ul>
<li><b>Pengurus lingkungan</b> Anda: data pendaftaran (untuk persetujuan) dan pelayanan di lingkungannya.</li>
<li><b>Romo dan paroki</b> yang menangani pelayanan Anda, serta <b>koordinator</b> yang mengatur penugasan.</li>
<li><b>Anggota grup chat</b> pelayanan: nama dan pesan Anda di grup tersebut.</li>
<li><b>Admin</b> CATU untuk pengelolaan dan bantuan teknis.</li>
</ul>
<p>Penyedia layanan yang membantu kami memproses data atas nama kami:</p>
<ul>
<li><b>Google Firebase Cloud Messaging</b>, untuk mengirim notifikasi ke perangkat Anda (token perangkat dan isi notifikasi).</li>
<li><b>Gerbang WhatsApp</b>, untuk mengirim kode verifikasi dan tautan masuk ke nomor HP Anda.</li>
<li><b>Penyimpanan server dan berkas</b>, untuk menyimpan data aplikasi, foto, dan lampiran.</li>
</ul>
<p>Data juga dapat kami ungkapkan bila diwajibkan oleh hukum yang berlaku.</p>

<h2>4. Keamanan</h2>
<p>Data dikirim melalui koneksi terenkripsi (HTTPS). Kata sandi disimpan dalam bentuk hash. Akses ke data dibatasi sesuai
peran: misalnya, umat hanya dapat melihat pelayanannya sendiri.</p>

<h2>5. Berapa lama data disimpan</h2>
<p>Data disimpan selama akun Anda aktif. Saat akun dihapus, data pribadi Anda langsung dihapus atau dianonimkan (lihat
bagian 6). Riwayat pelayanan tanpa identitas Anda tetap disimpan sebagai catatan paroki. Salinan cadangan server ikut
terhapus sesuai siklus cadangan.</p>

<h2>6. Menghapus akun</h2>
<p>Buka aplikasi CATU, lalu <b>Profil → Akun → Hapus Akun</b>, dan masukkan kata sandi Anda. Akibatnya:</p>
<ul>
<li>Nama diganti "Pengguna terhapus". Email, alamat, tanggal lahir, jenis kelamin, dan foto dihapus.</li>
<li>Token notifikasi, notifikasi, dan keanggotaan grup chat dihapus. Anda tidak dapat masuk lagi dengan akun tersebut.</li>
<li>Nomor HP Anda dilepas dari akun dan dapat dipakai untuk mendaftar kembali sebagai akun baru.</li>
<li>Riwayat pelayanan dan pesan yang pernah dikirim ke grup tetap ada atas nama "Pengguna terhapus".</li>
</ul>
<p>Pelayanan yang masih berjalan harus selesai atau dibatalkan terlebih dahulu. Bila Anda tidak dapat masuk ke aplikasi,
ajukan penghapusan melalui ${reach}.</p>

<h2>7. Hak Anda</h2>
<p>Sesuai Undang-Undang Nomor 27 Tahun 2022 tentang Pelindungan Data Pribadi, Anda berhak:</p>
<ul>
<li>mengakses dan memperbaiki data Anda melalui menu <b>Profil</b>;</li>
<li>menghapus akun (bagian 6);</li>
<li>meminta salinan data atau mengajukan keberatan melalui ${reach}.</li>
</ul>

<h2>8. Perubahan kebijakan</h2>
<p>Bila kebijakan ini berubah, tanggal berlaku di atas diperbarui.</p>

<h2>9. Kontak</h2>
<p>Pertanyaan tentang privasi dapat disampaikan kepada ${name} melalui ${reach}.</p>
</main></body></html>`;
}
