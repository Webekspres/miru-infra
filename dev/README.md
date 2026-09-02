# Dev infra (Podman) — PostgreSQL + MinIO

Hanya database dan object storage. Backend, web, dan mobile dijalankan di **host**.

## Nyalakan / matikan

```bash
cd infra/dev
podman compose up -d      # start
podman compose ps         # cek status
podman compose down       # stop (data tetap di volume)
podman compose down -v    # stop + hapus volume (reset DB/MinIO)
```

| Service | Port | Kredensial default |
|---------|------|-------------------|
| PostgreSQL | `5432` | DB `miru`, user `postgres`, pass `postgres` |
| MinIO API | `9000` | user `minioadmin`, pass `minioadmin` |
| MinIO Console | `9001` | sama |

Bucket `mirubanksampah` dibuat otomatis oleh service `minio-init`.

## Backend `.env` (host)

Pastikan `backend/.env` memakai host lokal (bukan hostname Docker):

```env
USE_POSTGRES=True
DB_HOST=127.0.0.1
DB_PORT=5432
MINIO_ENDPOINT=http://localhost:9000
```

## Jalankan aplikasi (3 terminal)

```bash
# 1 — Backend
cd backend
source venv/bin/activate
python manage.py migrate          # pertama kali / setelah pull
python manage.py seed_data --minimal --flush   # opsional: data demo
python manage.py runserver 0.0.0.0:8000

# 2 — Web admin
cd web
bun run dev

# 3 — Mobile (emulator / device)
export PATH="$HOME/.local/share/flutter/bin:$PATH"
cd mobile
flutter pub get
flutter run
```

Web: http://localhost:3000 · API: http://localhost:8000 · Health: http://localhost:8000/health/
