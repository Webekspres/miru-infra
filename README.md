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
~developer/miru-edge/           ← runtime proxy edge (SATU-SATUNYA pemegang port 80/443;
│                                  di home user deploy karena /opt butuh sudo)
│   ├── conf.d/                 ← disalin dari miru-infra/edge/
│   ├── certs/                  ← data certbot; current/{staging,production} → sertifikat aktif
│   └── webroot/                ← tantangan ACME
├── miru-staging/               ← runtime staging: .env + db/minio/api/admin
└── miru-prod/                  ← runtime production: .env + db/minio/api/admin
```

### Proxy edge

Satu nginx di `~developer/miru-edge` meneruskan per host lewat jaringan Docker
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

## Backup (sekali per environment)

Harian 02.00: dump Postgres + objek MinIO, terenkripsi GPG AES-256, disimpan di
`~developer/miru-backups/<env>/` (harian 14 hari, mingguan 90 hari). Dump DB
diverifikasi setiap kali backup. Passphrase: `~developer/miru-backups/.passphrase`
— **simpan salinannya di luar VPS**. Cara pulih ada di kepala `scripts/backup.sh`.

```bash
bash /opt/miru-infra/scripts/backup.sh production install-cron
bash /opt/miru-infra/scripts/backup.sh staging install-cron
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
sudo git clone -b main https://github.com/Webekspres/miru-infra.git /opt/miru-infra
sudo chown -R developer:developer /opt/miru-infra
bash /opt/miru-infra/scripts/cleanup-vps.sh
```

## Deploy

Repo ini **satu branch: `main`**. Pengaturan tiap environment ada di foldernya
sendiri, jadi workflow dipicu per folder:

| Perubahan di | Workflow | Aksi di VPS |
|--------------|----------|-------------|
| `staging/**` | *Deploy infra (staging)* | `scripts/deploy.sh staging` → `/opt/miru-staging` |
| `production/**` | *Deploy infra (production)* | `scripts/deploy.sh production` → `/opt/miru-prod` |
| `edge/**`, `scripts/**` | keduanya | proxy edge & script bersama |

Keduanya juga bisa dijalankan manual (Actions → *Run workflow*). Di VPS hanya
ada satu clone: `/opt/miru-infra` (branch `main`).

Aplikasi punya pipeline sendiri: push `staging`/`main` di **miru-backend-api**
dan **miru-web-admin** men-deploy image ke `/opt/miru-staging` / `/opt/miru-prod`.

Secrets GitHub environment `staging` & `production`: `SSH_HOST`, `SSH_PORT`, `SSH_USER`, `SSH_PRIVATE_KEY`

CI deploy **tanpa sudo** — user SSH (`developer`) harus sudah punya ownership `/opt/miru-infra` dan `/opt/miru-staging` (setup sekali manual di atas).
