# MIRU Infra

Infrastruktur deploy VPS untuk MIRU Bank Sampah.

**Clone lokal (monorepo MIRU):** `miru/miru-infra/` — jangan pindah ke path lain; repo GitHub terpisah `Webekspres/miru-infra`.

## Layout VPS (`/opt`)

```
/opt/
├── miru-infra/                 ← git clone (sumber compose/nginx/script)
│   ├── edge/                   ← proxy edge: docker-compose + conf.d + production.conf
│   ├── staging/                ← template stack staging
│   ├── production/             ← template stack production
│   └── scripts/
│       ├── sync-staging.sh     ← salin template → runtime, lalu sync-edge
│       ├── sync-production.sh
│       ├── sync-edge.sh        ← pasang/muat ulang proxy edge
│       ├── edge-certs.sh       ← Let's Encrypt (webroot) + cron perpanjangan
│       └── install-cron.sh
│
├── miru-edge/                  ← runtime proxy edge (SATU-SATUNYA pemegang port 80/443)
│   ├── conf.d/                 ← disalin dari miru-infra/edge/
│   ├── certs/                  ← data certbot; current/{staging,production} → sertifikat aktif
│   └── webroot/                ← tantangan ACME
├── miru-staging/               ← runtime staging: .env + db/minio/api/admin
└── miru-prod/                  ← runtime production: .env + db/minio/api/admin
```

### Proxy edge

Satu nginx di `/opt/miru-edge` meneruskan per host lewat jaringan Docker
`miru-edge` (alias `staging-api`, `staging-admin`, `prod-api`, `prod-admin`).
Database & MinIO tiap stack tetap terpisah dan tidak masuk jaringan edge.

| Host | Tujuan |
|------|--------|
| `dev.mirubanksampah.id` | staging web |
| `api.dev.mirubanksampah.id` | staging API |
| `mirubanksampah.id` | production web; `/api/` & `/objects/` → API (cookie host-only) |
| `www.mirubanksampah.id` | redirect → `mirubanksampah.id` |
| `api.mirubanksampah.id` | production API (aplikasi mobile) |

Sertifikat (sekali, lalu otomatis diperpanjang):

```bash
bash /opt/miru-infra/scripts/edge-certs.sh staging
bash /opt/miru-infra/scripts/edge-certs.sh production && bash /opt/miru-infra/scripts/sync-edge.sh
bash /opt/miru-infra/scripts/edge-certs.sh install-cron
```

### Kenapa compose ada di dua tempat?

| Lokasi | Peran |
|--------|-------|
| `miru-infra/staging/` | **Template** di git — diedit developer, di-deploy via CI |
| `miru-staging/` | **Runtime** — disalin otomatis + `.env`/`certs` lokal |

Bukan duplikasi acak: infra = sumber, staging = tempat `docker compose` jalan.

### Folder yang DIHAPUS saat cleanup

| Path | Alasan |
|------|--------|
| `/opt/miru/` | Legacy kosong (`staging/`, `production/` subfolder tanpa isi) |
| `miru-staging/admin/` | Rsync lama — compose pakai image GHCR |
| `miru-staging/backend/` | Rsync lama — compose pakai image GHCR |
| `miru-staging/Caddyfile` | Diganti nginx di compose |

## Rapikan VPS (sekali)

```bash
bash /opt/miru-infra/scripts/cleanup-vps.sh
```

## Cron harian (sekali per environment)

Hapus pendaftaran nasabah yang tidak memverifikasi email dalam 24 jam
(02.30 waktu server, log di `<env>/logs/cron.log`). Aman dijalankan ulang.

```bash
bash /opt/miru-infra/scripts/install-cron.sh staging
bash /opt/miru-infra/scripts/install-cron.sh production   # setelah prod siap
```

## Setup awal / migrasi

```bash
sudo git clone -b staging https://github.com/Webekspres/miru-infra.git /opt/miru-infra
sudo chown -R developer:developer /opt/miru-infra
bash /opt/miru-infra/scripts/cleanup-vps.sh
```

## Deploy

| Trigger | Repo | Aksi |
|---------|------|------|
| Push `staging` | **miru-infra** | git pull `/opt/miru-infra` + `sync-staging.sh` |
| Push `staging` | **miru-backend-api** | `docker compose pull api` di `/opt/miru-staging` |
| Push `staging` | **miru-web-admin** | `docker compose pull admin` di `/opt/miru-staging` |

Secrets GitHub environment `staging`: `SSH_HOST`, `SSH_PORT`, `SSH_USER`, `SSH_PRIVATE_KEY`

CI deploy **tanpa sudo** — user SSH (`developer`) harus sudah punya ownership `/opt/miru-infra` dan `/opt/miru-staging` (setup sekali manual di atas).
