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
Aplicar al provisionar el VPS (GCE). Marca al completar en el primer `kamal setup` (AUD-011).
- [ ] **Firewall GCP:** default-deny inbound. Abrir solo **443** (y **80** para el challenge de
      Let's Encrypt). **NUNCA abrir 5432** — Postgres queda bindeado a `127.0.0.1` (ver `deploy.yml`).
- [ ] **SSH:** solo con llave (password auth off). Preferible **IAP TCP forwarding** de GCP para
      sacar el puerto 22 del internet público. Si no, `fail2ban`.
- [ ] **GCP IAM:** service account de la VM con **mínimo privilegio** (no la default con scopes amplios).
- [ ] **Exposición:** decidir Camino A (DuckDNS + Let's Encrypt público, login endurecido) vs
      Camino B (**Tailscale**, sin login público). Para 1 usuario, B minimiza superficie.
- [ ] **Password de la app:** fuerte y única (cambiar cualquier clave temporal de dev).
- [ ] **Secrets:** `.kamal/secrets` jamás con valores crudos; salen de ENV/gestor. `master.key`
      nunca en git. `POSTGRES_PASSWORD` = `OTEO_DATABASE_PASSWORD`, random y fuerte.
- [ ] **Backup cifrado:** definir `BACKUP_AGE_RECIPIENT` (clave pública age); la privada vive
      **fuera del VPS** (ver §5). Completar el destino off-site en `script/pg_backup.sh`.
- [ ] **Registry token:** scope mínimo (solo la imagen de Oteo).
- [ ] **Pre-lanzamiento (opcional, barato):** un scan **OWASP ZAP baseline** contra la URL.

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
