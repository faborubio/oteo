# DEPLOY.md — Puesta en producción con Kamal (AUD-011)

> ⚠️ **Config preparada, NO validada contra un VPS real.** Estos pasos son la guía; la primera
> corrida necesita el VPS, los secrets reales y verificación humana. Kamal 2 + Postgres en
> contenedor + backups (ADR-010).

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

## Pendiente de validar (mantener en AUD-011 hasta hacerlo)
- [ ] Primer `kamal setup` real sin errores.
- [ ] `db:prepare` crea las 4 bases (primary + cache/queue/cable).
- [ ] Recurring dispara `SyncAllJob` y `ExpirePlacesDataJob`.
- [ ] Backup externo + restauración probada.
