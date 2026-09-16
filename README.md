# CATU v2 — Platform Pelayanan Umat & Romo Gereja Katolik

Sistem informasi dan operasional on-demand pelayanan sakramen Romo, misa kedukaan multi-item, alur persetujuan registrasi umat/pengurus, obrolan grup terintegrasi, dan portal administrasi gereja.

---

## 🏛️ Arsitektur Repository

Repository ini terdiri dari 3 codebase utama:

| Codebase | Direktori | Stack | Keterangan |
| :--- | :--- | :--- | :--- |
| **Backend** | [`backend/`](./backend) | NestJS 11, TypeORM, PostgreSQL 16, JWT, Helmet, Swagger | authoritative backend REST API (`port 3005:3000`) |
| **Mobile** | [`mobile/`](./mobile) | Flutter (Dart >=3.0), Firebase Messaging, HTTP | Aplikasi mobile Android & iOS untuk Umat, Pengurus, & Romo |
| **Admin Web** | [`admin_web/`](./admin_web) | HTML5, Tailwind CSS, Lucide Icons, Nginx | Portal web tunggal operasional administrator (`port 8000:80`) |

Service pendukung lainnya:
- **SearXNG**: Meta search engine lokal untuk agregasi warta berita gereja (`port 8080`).

---

## 🚀 Menjalankan Project dengan Docker (Production Mode)

Jalankan seluruh service container (PostgreSQL, Backend API, Admin Web, dan SearXNG) di latar belakang:

```bash
docker compose up -d --build
```

### Akses Layanan Lokal
- **Admin Web Portal:** [http://localhost:8000](http://localhost:8000)
- **Backend Health Check:** [http://localhost:3005/health](http://localhost:3005/health)
- **Swagger OpenAPI Docs:** [http://localhost:3005/api/docs](http://localhost:3005/api/docs)
- **SearXNG Engine:** [http://localhost:8080](http://localhost:8080)

---

## 📱 Menjalankan Aplikasi Mobile (Flutter)

Masuk ke direktori `mobile/`:

```bash
cd mobile

# Mengambil dependencies
flutter pub get

# Menjalankan di perangkat Android terhubung
flutter run
```

---

## 🛡️ Engineering Guard & Quality Policy

Prosedur pengujian kualitas diatur melalui `.agents/scripts/engineering-guard.sh`:

```bash
./.agents/scripts/engineering-guard.sh <codebase> <fast|full|release>
```
