#!/usr/bin/env bash
# Backup diario de la BD de Oteo (ADR-010). El dato propio (pipeline, notas, pos_status)
# es lo único irreemplazable: los datos de Google se re-sincronizan, las notas no.
#
# Uso (en el VPS, vía cron):
#   BACKUP_AGE_RECIPIENT=age1... BACKUP_GCS_BUCKET=oteo-backups-... script/pg_backup.sh
# El Postgres de producción corre en el contenedor `oteo-db` (accessory de Kamal, ADR-010):
# si no hay pg_dump en el host, el dump se hace vía `docker exec`.
set -euo pipefail

DB="${OTEO_DB:-oteo_production}"
DB_CONTAINER="${OTEO_DB_CONTAINER:-oteo-db}"
DEST="${BACKUP_DIR:-$HOME/backups}"
STAMP="$(date +%Y%m%d-%H%M%S)"
FILE="${DEST}/oteo-${STAMP}.sql.gz"

mkdir -p "$DEST"
echo "→ Respaldando ${DB} a ${FILE}"
# --no-owner --no-acl: el dump restaura limpio en cualquier rol (la prueba de ADR-010
# se hace en la máquina local, donde el rol "oteo" no existe).
if command -v pg_dump >/dev/null; then
  pg_dump --no-owner --no-acl "$DB" | gzip > "$FILE"
else
  sudo docker exec "$DB_CONTAINER" pg_dump --no-owner --no-acl -U oteo "$DB" | gzip > "$FILE"
fi

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

# Envío off-site a GCS (obligatorio — ADR-010). Auth vía metadata token de la VM (scope
# devstorage.read_write): cero credenciales en disco. Solo sube el CIFRADO.
if [[ -z "${BACKUP_GCS_BUCKET:-}" ]]; then
  echo "✖ Falta BACKUP_GCS_BUCKET. El backup quedó local pero NO off-site (ADR-010)." >&2
  exit 1
fi
TOKEN="$(curl -s -H 'Metadata-Flavor: Google' \
  'http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token' \
  | grep -o '"access_token":"[^"]*' | cut -d'"' -f4)"
HTTP_CODE="$(curl -s -o /dev/null -w '%{http_code}' -X POST \
  -H "Authorization: Bearer ${TOKEN}" -H 'Content-Type: application/octet-stream' \
  --data-binary @"${ENC}" \
  "https://storage.googleapis.com/upload/storage/v1/b/${BACKUP_GCS_BUCKET}/o?uploadType=media&name=$(basename "$ENC")")"
if [[ "$HTTP_CODE" != "200" ]]; then
  echo "✖ Upload a gs://${BACKUP_GCS_BUCKET} falló (HTTP ${HTTP_CODE})." >&2
  exit 1
fi

# Restaurar (con la clave privada offline):
#   age -d -i key.txt oteo-YYYYMMDD.sql.gz.age | gunzip | psql oteo_restore_test
echo "✔ Backup listo y subido: gs://${BACKUP_GCS_BUCKET}/$(basename "$ENC")"
