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

# Cifrado para el envío OFF-SITE (SECURITY.md §5, ADR-010). El valor del cifrado está en la
# copia que sale del VPS (el dump local ya vive junto a la BD, que está en claro). Usamos age
# asimétrico: el VPS solo tiene la clave PÚBLICA (BACKUP_AGE_RECIPIENT) → cifra pero NO descifra;
# la privada vive offline. Así un VPS comprometido no expone los backups históricos.
if [[ -z "${BACKUP_AGE_RECIPIENT:-}" ]]; then
  echo "✖ Falta BACKUP_AGE_RECIPIENT (clave pública age). No se cifra ni se sube (SECURITY.md §5)." >&2
  echo "  Genera el par offline: age-keygen -o key.txt → usa la línea 'public key:' como recipient." >&2
  exit 1
fi
command -v age >/dev/null || { echo "✖ 'age' no está instalado en el VPS (apt install age)." >&2; exit 1; }

ENC="${FILE}.age"
age -r "$BACKUP_AGE_RECIPIENT" -o "$ENC" "$FILE"
echo "→ Cifrado off-site: ${ENC}"

# Retención local: conserva los últimos 14 de cada tipo (dump en claro y cifrado).
ls -1t "${DEST}"/oteo-*.sql.gz     | tail -n +15 | xargs -r rm -f
ls -1t "${DEST}"/oteo-*.sql.gz.age | tail -n +15 | xargs -r rm -f

# TODO(deploy): copiar SOLO el cifrado ($ENC) a un destino externo (obligatorio — ADR-010):
#   rclone copy "$ENC" remote:oteo-backups/
#   aws s3 cp "$ENC" s3://mi-bucket/oteo-backups/
# Restaurar (con la clave privada offline):
#   age -d -i key.txt oteo-YYYYMMDD.sql.gz.age | gunzip | psql oteo_restore_test
echo "✔ Backup listo: ${FILE} (+ cifrado ${ENC})"
echo "⚠ Falta completar el destino off-site (TODO) y PROBAR una restauración una vez (ADR-010)."
