# MIRU Infra

Infrastruktur deploy VPS untuk ekosistem MIRU Bank Sampah — Docker Compose, nginx, MinIO, PostgreSQL.

Aplikasi (`miru-backend-api`, `miru-web-admin`, `mirumobileapp`) **tidak** disimpan di sini; stack ini menarik image dari GHCR.

## Layout

| Path | Deploy target VPS | Isi |
|------|-------------------|-----|
| `staging/` | `/opt/miru-staging` | Compose staging + nginx |
| `production/` | `/opt/miru-prod` | Compose production + nginx |

File `.env` dan `certs/` **tidak** di-repo — tetap di VPS.

## Staging

Services: `db`, `minio`, `minio-init`, `api`, `admin`, `nginx`

| Host | Service |
|------|---------|
| `dev.mirubanksampah.id` | web-admin |
| `api.dev.mirubanksampah.id` | backend API + `/objects/` → MinIO |

### Setup awal VPS

```bash
sudo mkdir -p /opt/miru-staging/certs
sudo chown -R developer:developer /opt/miru-staging
cd /opt/miru-staging
# Salin .env dari template, isi DB_* dan SECRET_KEY
cp /path/to/staging/.env.example .env
chmod 600 .env
# Letakkan sertifikat TLS di certs/live/dev.mirubanksampah.id/
```

### Deploy manual

```bash
cd /opt/miru-staging
docker compose pull api   # opsional — admin image harus sudah ada di server
docker compose up -d
```

### Deploy otomatis (CI)

Push ke branch `staging` → workflow sync `staging/*` ke VPS dan `docker compose up -d`.

GitHub Environment **`staging`** membutuhkan secrets (sama seperti backend dulu):

- `SSH_HOST`
- `SSH_PORT` (opsional, default 22022)
- `SSH_USER` (opsional, default `developer`)
- `SSH_PRIVATE_KEY`

## Production

Push ke branch `main` → deploy ke `/opt/miru-prod` (environment **`production`**).

## Hubungan dengan repo aplikasi

| Repo | Tanggung jawab deploy |
|------|------------------------|
| **miru-infra** (ini) | Stack: db, minio, nginx, compose — `docker compose up -d` |
| **miru-backend-api** | Build image → GHCR → `docker compose pull api && up -d api` |
| **miru-web-admin** | Build image → GHCR → `docker compose pull admin && up -d admin` |

Ubah nginx, MinIO, atau Postgres → **miru-infra**.  
Rilis kode API/admin → repo masing-masing.
