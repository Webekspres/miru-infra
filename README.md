# MIRU Infra

Infrastruktur deploy VPS untuk MIRU Bank Sampah.

## Layout VPS (`/opt`)

```
/opt/
├── miru-infra/      ← git clone repo ini (sumber compose + nginx)
├── miru-staging/    ← runtime staging (.env, certs, docker aktif)
└── miru-prod/       ← runtime production (nanti)
```

| Folder | Isi | Di git? |
|--------|-----|---------|
| `/opt/miru-infra` | Repo infra, scripts | ✅ clone GitHub |
| `/opt/miru-staging` | `.env`, `certs/`, compose aktif | ❌ secrets lokal |
| `admin/`, `backend/` di staging | Legacy rsync | ❌ tidak dipakai compose |

## Migrasi `~/miru-infra` → `/opt/miru-infra`

```bash
bash /opt/miru-infra/scripts/install-opt-layout.sh
bash /opt/miru-infra/scripts/sync-staging.sh
```

## Deploy

| Trigger | Repo | Aksi |
|---------|------|------|
| Push `staging` | **miru-infra** | git pull `/opt/miru-infra` + sync stack |
| Push `staging` | **miru-backend-api** | `pull api` saja |
| Push `staging` | **miru-web-admin** | `pull admin` saja |

Secrets environment `staging`: `SSH_HOST`, `SSH_PORT`, `SSH_USER`, `SSH_PRIVATE_KEY`
