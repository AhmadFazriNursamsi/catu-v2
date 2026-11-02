# Rilis APK CATU (dikirim langsung, tanpa Play Store)

## Membangun
```bash
# 1. naikkan versi di pubspec.yaml (version: X.Y.Z+KODE; KODE harus lebih besar dari rilis sebelumnya)
#    dan samakan AppConstants.appVersion (lib/core/constants/app_constants.dart) menjadi 'vX.Y.Z'
# 2. bangun (alamat server: CATU_RELEASE_API_URL, bawaan https://catu.devoutsys.com/api; .env TIDAK dipakai)
./scripts/mobile/build_production.sh apk
```
Skrip menjalankan analisis dan seluruh tes, membangun APK berobfuskasi, lalu **memeriksa otomatis** hasilnya dan berhenti bila:
kunci tanda tangan adalah kunci debug, versionCode tidak sama dengan pubspec, APK masih mengizinkan HTTP tanpa enkripsi atau
berstatus debuggable, alamat server tidak tertanam, atau ada alamat jaringan lokal di dalamnya.
Hasil: `build/release/catu-v<versi>-<kode>.apk` beserta berkas `.sha256`.

## Kunci tanda tangan (PENTING)
- Android hanya mau **memperbarui** aplikasi bila APK baru ditandatangani dengan kunci yang **sama** dengan yang terpasang.
  Bila kunci hilang, tidak ada cara memperbarui aplikasi: semua pengguna harus mencopot dan memasang ulang (data masuk hilang).
- Kunci rilis: `android/catu-release.jks` + `android/key.properties` (sandi). Keduanya **diabaikan git**.
  **Cadangkan keduanya** di dua tempat aman terpisah (mis. pengelola kata sandi dan penyimpanan terenkripsi). Jangan dikirim lewat chat/email biasa.
- Build rilis tanpa `key.properties` sengaja **gagal** (tidak pernah memakai kunci debug).
- **Sidik jari resmi** (SHA-256) tercatat di `mobile/release-cert.sha256`; `build_production.sh` menolak APK yang ditandatangani kunci lain.
  Kunci saat ini dibuat 2 Nov 2026 (alias `catu`, RSA 4096, berlaku s.d. 2054): `B7:1F:B5:BF:80:00:D5:9B:0D:A6:A8:F3:9E:F7:B5:2C:27:5F:9D:0A:3E:5C:CD:B0:41:C7:78:B2:8B:AA:D2:E1`.
- Kunci sebelumnya (dipakai APK 2.9.35/2.9.36, SHA-256 `2B:F0:1B:E2:…:83:2E:16`) hilang pada 30 Okt 2026 dan tidak ditemukan; pengguna 2.9.36
  harus mencopot dan memasang ulang sekali untuk beralih ke kunci ini.
- **Aturan cadangan (wajib, jangan dilewati):** `catu-release.jks` dan `key.properties` ada di (1) `android/` yang dikunci `chflags uchg`,
  (2) `~/Backups/catu-release-key/` (di luar iCloud, juga `uchg`; berisi `SHA256SUMS.txt` dan `catu-release-key-bundle.tar`), dan (3) **satu salinan di luar Mac**
  (pengelola kata sandi atau flashdisk) yang disimpan pemilik. Jangan menghapus folder proyek/duplikat sebelum ketiganya ada. Uji cadangan:
  `keytool -list -v -keystore ~/Backups/catu-release-key/catu-release.jks | grep SHA256` harus sama dengan sidik jari di atas.
- Mengganti kunci memerlukan sidik jari baru di `mobile/release-cert.sha256` dan cadangan baru di tiga tempat itu SEBELUM APK dibangun.
- APK memakai tanda tangan v2 dan v3, sehingga penggantian kunci di masa depan (rotasi) dimungkinkan tanpa pasang ulang.
- Jangan pernah mengubah `applicationId` (`com.example.catu_mobile`): aplikasi dianggap berbeda dan pengguna tidak bisa memperbarui.

## Build debug vs rilis di satu HP
Build debug (uji lokal ke backend LAN, HTTP diizinkan) ditandatangani kunci debug; build rilis memakai kunci rilis. Android menolak
menimpa salah satunya dengan yang lain: pindah di antara keduanya perlu `adb uninstall com.example.catu_mobile` (data masuk hilang).

## Distribusi
Unggah APK lewat menu **Pengaturan Aplikasi** di Admin Web (QR dan tautan unduh), atau kirim berkasnya langsung.
Bisa juga lewat skrip: `ADMIN_PHONE=62... ADMIN_PASSWORD='...' ./scripts/mobile/deploy_apk.sh` (kredensial hanya dari environment,
tidak ada nilai bawaan). Skrip menolak APK debug, APK yang SHA-256-nya tidak cocok dengan berkas `.sha256`, dan alamat non-https.
**Skrip ini mengunggah ke server produksi: jalankan hanya oleh manusia yang berwenang, bukan oleh agen.** Sertakan nilai
SHA-256 agar penerima dapat memastikan berkas tidak berubah (`shasum -a 256 <berkas>`).
Pengguna perlu mengizinkan "pasang dari sumber tidak dikenal" untuk aplikasi yang dipakai membuka berkasnya.

## Setelah rilis
- Simpan `build/symbols/<versi>+<kode>` (diperlukan membaca jejak crash dari build berobfuskasi).
- Catat SHA-256 dan versi yang dibagikan.
