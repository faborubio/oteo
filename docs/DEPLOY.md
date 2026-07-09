# DEPLOY.md — Puesta en producción con Kamal (AUD-011)

> ✅ **Validado en producción real el 2026-07-09** (AUD-011 pagado): VM GCE `e2-small` en
> `southamerica-west1`, IP estática `34.176.45.178`, `https://oteo.duckdns.org` (Let's Encrypt),
> Postgres en contenedor, backups cifrados a GCS con restauración probada. Deploys posteriores:
> `bundle exec kamal deploy`. Los pasos de abajo quedan como runbook de re-provisión.

## 0. Requisitos
- VPS con Docker y acceso SSH (el `root` o un usuario con Docker).
- Un dominio apuntando (A record) a la IP del VPS.
- Un registry de imágenes (ghcr.io, Docker Hub…) con un token de acceso.

## 1. Completar los placeholders (`TODO(deploy)`)
En `config/deploy.yml`:
- `servers.web` → IP del VPS.
- `proxy.host` → dominio real.
- `registry.server` / `registry.username` → tu registry.
- `accessories.db.host` → misma IP del VPS.

## 2. Secrets (`.kamal/secrets`, nunca en git)
El archivo lee de ENV / password manager. Se necesitan:
- `RAILS_MASTER_KEY` = contenido de `config/master.key`.
- `KAMAL_REGISTRY_PASSWORD` = token del registry.
- `OTEO_DATABASE_PASSWORD` = contraseña de la BD (elígela).
- `POSTGRES_PASSWORD` = **el mismo valor** que `OTEO_DATABASE_PASSWORD` (lo usa el accessory).
- `GOOGLE_PLACES_API_KEY` = key de Places (server, IP-restringida a la IP del VPS).

## 3. Primer deploy
```bash
kamal setup          # instala Docker si falta, arranca proxy + accessory Postgres + app
# La BD primary (oteo_production) la crea el accessory; las de Solid (cache/queue/cable)
# se crean con db:prepare:
kamal app exec 'bin/rails db:prepare'
kamal app exec 'OTEO_ADMIN_EMAIL=tu@mail OTEO_ADMIN_PASSWORD=secreto bin/rails db:seed'
```
Deploys posteriores: `kamal deploy`.

## 4. Backups (ADR-010) — obligatorio antes de confiar en producción
Backups **cifrados off-site** (ver SECURITY.md §5). Cifrado asimétrico con `age`: el VPS solo
tiene la clave pública; la privada vive **offline** (tu máquina), así un VPS comprometido no
expone los backups históricos.
1. **Offline (tu máquina):** genera el par → `age-keygen -o key.txt`. Guarda `key.txt` (la clave
   privada) fuera del VPS. La línea `public key: age1...` es el recipient.
2. **En el VPS:** `apt install age`; exporta `BACKUP_AGE_RECIPIENT=age1...`; copia `script/pg_backup.sh`.
3. Completar el `TODO` del script: subir **solo el `.age`** a un destino externo (rclone/S3).
4. Cron diario, ej. `0 5 * * * BACKUP_AGE_RECIPIENT=age1... /ruta/script/pg_backup.sh`.
5. **Probar una restauración** una vez (requisito ADR-010), con la clave privada offline:
   ```bash
   age -d -i key.txt oteo-YYYYMMDD.sql.gz.age | gunzip | psql oteo_restore_test
   ```

## 5. Health check post-deploy
- `https://<dominio>/up` → 200 (health de Rails).
- Iniciar sesión → `/salud` → cuota, vencidos, jobs.
- Verificar que el recurring corre (`config/recurring.yml`: sync quincenal + expiración).

## Validado (AUD-011 🟢, 2026-07-09)
- [x] Primer `kamal setup` real sin errores (~27 min el primer build).
- [x] `db:prepare` creó las 4 bases (primary + cache/queue/cable).
- [x] Recurring registrado; `SyncAllJob` corrió en producción (96/96, 2237 negocios, 180 llamadas).
- [x] Backup cifrado (age) a `gs://oteo-backups-501721` + **restauración probada** (ADR-010 ✓).

## Realidad operativa (lo que quedó distinto del plan genérico)
- **Host:** VM GCE, no VPS tradicional. SSH como `faborubio` (llave ed25519 en metadata), no root
  → `ssh.user` en `deploy.yml` y Docker preinstalado a mano (Kamal no bootstrapea sin root).
- **Secrets:** los valores crudos viven en `.env` (gitignoreado); `.kamal/secrets` (trackeado)
  solo referencia — la Places key sale de Rails credentials vía `bin/rails runner`.
- **Backup:** cron en `/etc/cron.d/oteo-backup` (05:00 UTC = 01:00 Chile), script en
  `~faborubio/pg_backup.sh` (copia de `script/pg_backup.sh`), sube SOLO el `.age` al bucket vía
  metadata token (scope `devstorage.read_write` + rol Object Admin acotado al bucket — ambos
  necesarios, ver TROUBLESHOOTING). Clave privada age: `~/.oteo-backup-age.key` en la máquina
  local del autor (¡respaldarla aparte!).
- **Deuda residual:** SSH 22 público (AUD-013) y permanencia GCE al expirar el crédito (AUD-014).
