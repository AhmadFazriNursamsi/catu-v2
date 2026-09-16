# CATU v2 — Platform Pelayanan Umat & Romo Gereja Katolik

Sistem informasi dan operasional on-demand pelayanan sakramen Romo, misa kedukaan multi-item, alur persetujuan registrasi umat/pengurus, obrolan grup terintegrasi, dan portal administrasi gereja.

---

## 🏛️ Arsitektur Repository

Repository ini terdiri dari 3 codebase utama:

| Codebase | Direktori | Stack | Keterangan |
| :--- | :--- | :--- | :--- |
| **Backend** | [`backend/`](./backend) | NestJS 11, TypeORM, PostgreSQL 16, JWT, Helmet, Swagger | authoritative backend REST API (`port 8001:3000`) |
| **Mobile** | [`mobile/`](./mobile) | Flutter (Dart >=3.0), Firebase Messaging, HTTP | Aplikasi mobile Android & iOS untuk Umat, Pengurus, & Romo |
| **Admin Web** | [`admin_web/`](./admin_web) | Vite, HTML5, Tailwind CSS, Lucide Icons | Portal web tunggal operasional administrator (`port 8000:80`) |

Service pendukung lainnya:
- **SearXNG**: Meta search engine lokal untuk agregasi warta berita gereja (`port 8080`).

---

## 🚀 Menjalankan Project dengan Docker (Production Mode)

CATU menggunakan shared infrastructure yang sudah berjalan, yaitu `shared-postgres` dan `shared-searxng` pada network Docker `shared-network`. Database yang dipakai adalah database `catu`; Compose CATU hanya membuat container aplikasi dan tidak membuat PostgreSQL, volume database, atau SearXNG baru.

Pastikan shared infrastructure aktif, lalu jalankan Backend API dan Admin Web di latar belakang:

Pada production build, fitur Agentation/inspector UI otomatis dihilangkan dari artifact Admin Web. Fitur tersebut hanya tersedia jika image dibangun dengan `NODE_ENV` non-production.

Admin Web memiliki menu **Pengaturan Aplikasi** dengan QR code dan tombol download APK. URL stabilnya dikonfigurasi melalui `PUBLIC_APK_URL`; backend mengambil credential AWS S3 dari Sensio Env saat runtime dan menerbitkan signed URL sementara melalui endpoint publik tersebut. Credential AWS tidak disimpan di frontend atau source code.

```bash
docker compose up -d --build
```

### Akses Layanan Lokal
- **Admin Web Portal:** [http://localhost:8000](http://localhost:8000)
- **Backend Health Check:** [http://localhost:8001/health](http://localhost:8001/health)
- **Swagger OpenAPI Docs:** [http://localhost:8001/api/docs](http://localhost:8001/api/docs)
- **Public APK Download:** `GET /public/apk` (redirect signed URL object storage)
- **Shared SearXNG Engine:** [http://localhost:8888](http://localhost:8888)

---

## 📱 Menjalankan Aplikasi Mobile (Flutter)

Masuk ke direktori `mobile/`:

```bash
cd mobile

# Mengambil dependencies
flutter pub get

# Menjalankan di perangkat Android terhubung dengan URL API dari environment
flutter run --dart-define=CATU_API_URL="$CATU_API_URL"
```

URL backend mobile dikirim melalui konfigurasi build, bukan ditulis di Dart. Script `mobile/run_android.sh` dan `mobile/run_ios.sh` otomatis membaca `PUBLIC_API_URL` dari `.env` root; override per environment dengan `CATU_API_URL=...`. Untuk menjalankan Flutter secara manual, gunakan `--dart-define=CATU_API_URL=...`.

---

## 🛡️ Engineering Guard & Quality Policy

Prosedur pengujian kualitas diatur melalui `.agents/scripts/engineering-guard.sh`:

```bash
./.agents/scripts/engineering-guard.sh <codebase> <fast|full|release>
```
