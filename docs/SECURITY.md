# SECURITY.md — Postura de seguridad (proporcional)

> Oteo es una herramienta **interna, de un solo usuario**. La seguridad aquí es *proporcional*:
> unos pocos controles de alto valor, no maquinaria organizacional (nada de ISO/COBIT/SIEM/SOAR
> formal — sería teatro de seguridad para un tool solo-usuario). Este doc es el registro vivo de
> lo que protegemos, de qué, y cómo. No es asesoría legal ni una certificación.

## 1. Modelo de amenaza (breve)
- **Qué protegemos:** (a) datos de contacto de negocios (nombre, dirección, teléfono — datos
  personales bajo Ley 19.628 / 21.719), (b) las **notas propias** del pipeline (irreemplazables:
  los datos de Google se re-sincronizan, las notas no), (c) las **API keys** de Google.
- **De quién:** bots y escaneo indiscriminado de internet, fuga de credenciales, error propio
  (borrado/corrupción). **Fuera de alcance:** un adversario dirigido con recursos (APT) — no es
  el perfil de riesgo de una herramienta interna de prospección.
- **Principio rector:** mínimo privilegio y mínima exposición (Zero Trust *aplicado en pequeño*):
  no exponer más de lo necesario, autenticar todo, restringir cada credencial a su uso.

## 2. Matriz de riesgo (top 6)
Probabilidad e impacto en Baja / Media / Alta. Enlaza con los `AUD-NNN` y ADR que ya los mitigan.

| # | Riesgo | Prob | Impacto | Mitigación | Ref |
|---|---|---|---|---|---|
| R1 | Fuga de la **Places API key** | Media | Media | Restringida por **IP** (inservible desde otra IP) + cupo mensual tope + budget alert. Rotar si se sospecha. | SAD §8, AUD-003 |
| R2 | **Compromiso del VPS** (RCE/SSH) | Baja | Alta | Firewall mínimo (solo 443, +80 para cert), SSH por **IAP/llave**, `force_ssl`+HSTS, imagen base al día. Recuperación: rebuild desde imagen + restore. | §3, ADR-010 |
| R3 | **Pérdida de datos** (borrado/corrupción de Postgres) | Baja | Alta | Backup diario **cifrado off-site** + **restauración probada** una vez. Las notas propias son el activo. | ADR-010, AUD-011 |
| R4 | **Fuerza bruta / acceso no autorizado** al login | Media | Alta | `rate_limit` en login (Rails 8) + password fuerte + HTTPS. Mejor: **exposición cero** (Tailscale) elimina el login público. | §3 |
| R5 | **Incumplir ToS de retención** de Places | Baja | Media | `ExpirePlacesDataJob` borra campos perecibles a 30 días; `place_id` permanente. | ADR-006, AUD-012 |
| R6 | **Agotar cuota / pasar a facturación** | Baja | Media | Cupo 1000/mes vigilado en `/salud` + budget alert + el sync aborta al agotar cuota (driver #2: jamás facturar). | AUD-003 |

## 3. Endurecimiento pre-deploy (checklist)
Aplicado en el primer `kamal setup` (AUD-011, 2026-07-09):
- [x] **Firewall GCP:** solo 22/80/443 inbound. 5432 cerrado — Postgres bindeado a `127.0.0.1`.
- [x] **SSH:** solo con llave ed25519 (GCE deshabilita password auth). ⚠️ El 22 sigue público
      (regla default de GCP) — **IAP pendiente como AUD-013** (riesgo bajo, llave obligatoria).
- [x] **GCP IAM:** el SA default de Compute quedó sin roles de proyecto; se le dio **solo**
      Storage Object Admin **acotado al bucket** de backups. Scope `devstorage.read_write`.
- [x] **Exposición:** Camino A (DuckDNS + Let's Encrypt público) con login rate-limited y
      `force_ssl`. Tailscale (Camino B) queda como opción futura si aparece ruido de bots.
- [x] **Password de la app:** fuerte, distinta a dev, seteada por el autor en el seed.
- [x] **Secrets:** `.kamal/secrets` solo referencia (valores en `.env` gitignoreado y en Rails
      credentials). `master.key` fuera de git. `POSTGRES_PASSWORD` random de 48 hex.
- [x] **Backup cifrado:** age asimétrico; pública en el cron de la VM, **privada offline** en
      `~/.oteo-backup-age.key` de la máquina local (respaldarla aparte). Off-site: GCS.
- [x] **Registry token:** PAT classic solo con `write:packages`/`read:packages`.
- [ ] **Pre-lanzamiento (opcional, barato):** scan **OWASP ZAP baseline** contra la URL.

## 4. Runbook de incidentes (si X → haz Y)
| Síntoma / evento | Respuesta inmediata |
|---|---|
| **Key de Google filtrada** (commit, log, screenshot) | Revocar/rotar la key en GCP → actualizar credentials/secret → `kamal deploy`. La restricción por IP contiene el daño mientras tanto. |
| **VPS comprometido** (proceso raro, login desconocido) | Aislar (cerrar firewall), snapshot forense, **rebuild desde imagen limpia** + `db:restore` del último backup, rotar TODOS los secrets. |
| **Postgres corrupto / datos perdidos** | Restaurar del backup off-site (§5). Re-sincronizar los datos de Google (`rake oteo:sync_all`); las notas propias vienen del backup. |
| **Brute force / picos de login** | `rate_limit` ya frena; si persiste, bloquear IP en firewall o pasar a Tailscale (exposición cero). |
| **Cuota de Places disparada** | `/salud` avisa; el sync ya aborta. Revisar `sync_runs`, budget alert. |

Todo incidente **resuelto** se documenta a fondo en [TROUBLESHOOTING.md](TROUBLESHOOTING.md) (postmortem).

## 5. Continuidad (DRP proporcional)
No hay ISO 22301 ni ITIL formal: el plan de recuperación **es** el backup + restore de ADR-010.
- Backup diario cifrado (`script/pg_backup.sh`), enviado **fuera del VPS**.
- **Cifrado asimétrico (age):** el VPS solo tiene la **clave pública** (`BACKUP_AGE_RECIPIENT`) →
  puede cifrar pero NO descifrar. La **clave privada vive offline** (tu máquina / gestor). Así, un
  VPS comprometido no expone los backups históricos.
- **Requisito ADR-010:** probar una restauración **una vez** antes de confiar en producción.
