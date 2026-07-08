#!/usr/bin/env bash
# Backup diario de la BD de Oteo (ADR-010). El dato propio (pipeline, notas, pos_status)
# es lo único irreemplazable: los datos de Google se re-sincronizan, las notas no.
#
# Uso (en el VPS, vía cron): script/pg_backup.sh
# Requiere: pg_dump accesible y las variables PGHOST/PGUSER/PGPASSWORD o DATABASE_URL.
# Envía el dump comprimido FUERA del VPS (bucket externo o segundo destino) — completar abajo.
set -euo pipefail

DB="${OTEO_DB:-oteo_production}"
DEST="${BACKUP_DIR:-/var/backups/oteo}"
STAMP="$(date +%Y%m%d-%H%M%S)"
FILE="${DEST}/oteo-${STAMP}.sql.gz"

mkdir -p "$DEST"
echo "→ Respaldando ${DB} a ${FILE}"
pg_dump "$DB" | gzip > "$FILE"

# Retención local: conserva los últimos 14 backups.
ls -1t "${DEST}"/oteo-*.sql.gz | tail -n +15 | xargs -r rm -f

# TODO(deploy): copiar FILE a un destino externo (obligatorio — ADR-010):
#   rclone copy "$FILE" remote:oteo-backups/
#   aws s3 cp "$FILE" s3://mi-bucket/oteo-backups/
echo "✔ Backup listo: ${FILE}"
echo "⚠ Falta enviar el backup fuera del VPS (ver TODO en el script) y PROBAR una restauración."
