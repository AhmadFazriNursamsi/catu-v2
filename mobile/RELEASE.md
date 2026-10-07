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
