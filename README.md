# MIRU Infra

Infrastruktur deploy VPS untuk MIRU Bank Sampah.

## Layout VPS (`/opt`) — setelah rapi

```
/opt/
├── miru-infra/                 ← git clone (SATU-SATUNYA sumber compose/nginx)
│   ├── staging/
│   │   ├── docker-compose.yml  ← template staging
│   │   ├── nginx.conf
│   │   └── env.example
│   ├── production/
│   └── scripts/
│       ├── sync-staging.sh     ← copy template → runtime
│       ├── sync-production.sh
│       ├── install-opt-layout.sh
│       └── cleanup-vps.sh      ← hapus legacy, rapikan VPS
│
├── miru-staging/               ← runtime staging (docker compose dijalankan DI SINI)
│   ├── docker-compose.yml      ← disalin dari miru-infra/staging/
│   ├── nginx.conf
│   ├── .env                    ← secrets (tidak di git)
│   └── certs/                  ← TLS (tidak di git)
│
└── miru-prod/                  ← runtime production (nanti)
    ├── .env
    └── certs/
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
