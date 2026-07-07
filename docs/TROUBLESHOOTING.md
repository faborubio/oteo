# TROUBLESHOOTING.md — Síntoma → causa → fix

> Todo incidente resuelto se registra aquí. Las fallas con impacto real (ej. un sync que
> pisó datos manuales) llevan una entrada más profunda: qué pasó, por qué, y qué cambió para
> que no se repita (SAD §14 fusionó aquí los postmortems).

---

## Entorno / setup

### `bundle install` falla con `Bundler::PermissionError` escribiendo en `/usr/local/rbenv/...`
**Causa:** los gems del sistema son de `root` y el usuario no tiene sudo. Bundler descarga el
gem pero no puede guardarlo en el path del sistema.
**Fix:** bundler está configurado para instalar en el proyecto —
`.bundle/config` → `BUNDLE_PATH: vendor/bundle` (gitignoreado). Si el error reaparece,
verificar que ese archivo existe. Consecuencia permanente: **usar siempre `bundle exec`**.

### Un binario (`rspec`, `rubocop`) usa una versión distinta o "no se encuentra"
**Causa:** se invocó el binario del sistema en vez del de `vendor/bundle`.
**Fix:** prefijar con `bundle exec` (o usar `bin/rspec`, `bin/rubocop`).

---

## Base de datos

### `ActiveRecord::PendingMigrationError` al correr specs
**Causa:** hay migraciones sin aplicar en la BD de test.
**Fix:** `bin/rails db:test:prepare`.

### `PG::ConnectionBad` / no conecta a Postgres
**Causa:** el servidor Postgres no está corriendo o el rol no existe.
**Fix:** `pg_isready` para confirmar; el rol del sistema debe existir en `pg_roles`.

---

## Google Places (Fase 1+)

### `PlacesClient::Result#error` con `HTTP 429` / `RESOURCE_EXHAUSTED`
**Causa:** cuota del SKU agotada (ADR-002).
**Fix:** el SyncJob debe abortar y alertar (driver #2: jamás pasar a facturación). Revisar
`SyncRun.api_calls_this_month` contra el cupo. Ver AUD-003.

### `HTTP 403` de una web al verificar presencia (Fase 4)
**Causa:** anti-bot; el sitio está vivo pero bloquea. **No** es `web_caida` (ADR-003).
**Fix:** solo DNS/timeout/5xx marcan `web_caida`; 403/405 se reintenta o se ignora.

<!--
Plantilla de postmortem (falla con impacto real):
### [FECHA] Título del incidente
**Qué pasó:** ...
**Por qué:** ...
**Qué cambió para que no se repita:** ... (link al commit / AUD / CASES)
-->
