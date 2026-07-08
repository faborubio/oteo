# CLAUDE.md — Contexto operativo de Oteo

> Lo primero que lee una sesión nueva (humana o IA). Objetivo: retomar el proyecto
> sin releer el historial de chats. Se actualiza al cerrar cada sesión que cambió el estado.

## Qué es Oteo
Dashboard interno de **prospección de negocios locales del Maule** sin presencia digital,
para vender (a) sitios web por plantilla y (b) un POS propio. Recorre Google Places por
comuna × rubro, clasifica la presencia digital y la candidatura POS de cada negocio,
calcula un lead score y convierte todo en un pipeline accionable (tabla + mapa + kanban).

Herramienta de **un solo usuario** (el autor). El diseño completo, las decisiones y sus
trade-offs viven en [SAD-Oteo.md](SAD-Oteo.md) — es la fuente de verdad. Este archivo solo
registra cómo operar el repo.

## Stack
Ruby 3.3 · Rails 8.1 · PostgreSQL 16 (jsonb) · Hotwire (Turbo + Stimulus) · Tailwind ·
Solid Queue/Cache/Cable · RSpec · RuboCop (omakase) · Brakeman · Kamal 2.
Mismo patrón que FleetPilot (repo hermano), con Postgres en vez de MySQL.

## Setup de entorno (importante)
Los gems del sistema son de `root` sin sudo, así que **bundler instala en `vendor/bundle`**
(`.bundle/config` → `BUNDLE_PATH: vendor/bundle`, gitignoreado). Consecuencia:
**siempre `bundle exec`** para correr binarios (rspec, rubocop, rails).

```bash
bundle install                 # instala en vendor/bundle
bin/rails db:create db:migrate # crea oteo_development y oteo_test
OTEO_ADMIN_EMAIL=tu@mail OTEO_ADMIN_PASSWORD=secreto bin/rails db:seed
```

## Comandos
| Acción | Comando |
|---|---|
| Tests | `bundle exec rspec` |
| Tests con cobertura | `COVERAGE=true bundle exec rspec` |
| Lint | `bundle exec rubocop` (autofix: `-A`) |
| Seguridad | `bin/brakeman --no-pager` · `bin/bundler-audit` · postura: [docs/SECURITY.md](docs/SECURITY.md) |
| Servidor dev | `bin/dev` (web + watcher de Tailwind) |
| Consola | `bin/rails console` |
| Migrar | `bin/rails db:migrate` |
| Seed (idempotente) | `bin/rails db:seed` |
| Datos demo (dev) | `bin/rails oteo:demo_data` |
| Deploy | `kamal deploy` (pendiente, AUD-011) |

## Configuración de dominio
- `config/oteo.yml` → dominios sociales, agregadores, acortadores (ADR-003), pesos del
  lead_score (ADR-008), ventana de retención ToS (ADR-006). Acceso vía
  `Rails.configuration.oteo`. **En configuración, no en código.**
- API key de Places: `ENV["GOOGLE_PLACES_API_KEY"]` o credentials `google.places_api_key`.
  Restringida por API + IP del VPS (SAD §8). Nunca en el repo.

## Arquitectura en una línea
Pipeline batch **sincronizar → clasificar → persistir**; todo lo demás son vistas sobre
`businesses`. `PlacesClient` es un adapter que emite `Snapshot` normalizado — el dominio
no sabe de Google (ADR-002). En tests el adapter se stubea con WebMock: cero llamadas reales.

## Pipeline de sync (Fase 1)
`SyncJob(comuna_id, rubro_id, query:)` — idempotente: upsert por `place_id`, agrega el rubro
sin reemplazar (ADR-013), NUNCA toca campos manuales, archiva cierres permanentes con evento
de sistema, audita `api_calls` en `sync_runs` y aborta sin reintentar si la cuota se agota
(driver #2). Clasificadores (PORO, lógica pura, testeable sin red):
- `PresenceClassifier` → `digital_presence` (ADR-003), listas en `config/oteo.yml`.
- `PosCandidateClassifier` → `pos_candidate` desde `types` (ADR-004).
- `LeadScorer` → `log(1+reseñas) × peso_presencia × bonus_pos` (ADR-008).
- `BusinessClassifier` → facade que aplica los tres en orden.

Disparar sync manual: `rake 'oteo:sync_now[curico,restaurantes]'` (síncrono, para auditar) ·
`rake oteo:sync_all` (encola todas las combinaciones activas). Necesita `GOOGLE_PLACES_API_KEY`.

## Modelo de datos (§6 del SAD)
`businesses` (central: `source` places/manual, `place_id` nullable con índice único parcial,
datos de Places + clasificación + datos propios) · `business_rubros` (n:m, agrega nunca
reemplaza) · `comunas` · `rubros` (con `text_search_query` + `pos_target`) · `sync_runs`
(auditoría de cuota) · `contact_events` (historial append-only, inmutable).

## Estado del roadmap
- **Fase 0 — Cimientos: ✅ COMPLETA.** Scaffold Rails 8 + Postgres + toolkit (RSpec/RuboCop/
  Brakeman/bundler-audit/Capybara-Cuprite/SimpleCov/WebMock/Pagy), auth nativa, modelos +
  migraciones (con `source` y `business_rubros` desde el día 1), taxonomías seed (48
  combinaciones), `PlacesClient` con specs WebMock, docs vivos, CI. Suite verde.
  - **Gates legales revisados 2026-07-07** (ver [docs/AUDIT.md](docs/AUDIT.md), no es asesoría legal):
    AUD-001 🟢 caché Places = 30 días, `place_id` indefinido (falta job de expiración, AUD-012).
    AUD-003 🟢 cupos por SKU confirmados, uso Enterprise ~144/1.000 mensuales. AUD-002 🟢
    **decisión: mapa con Google Maps JS API** (plotea Places + manuales sin violar ToS).
    AUD-004 🟢 marca "Oteo" libre en INAPI; dominio no bloquea. **Pendiente: conseguir la
    Places API key (server, IP-restringida) y la Maps JS key (browser, referrer-restringida).**
- **Fase 1 — Pipeline de datos: ✅ COMPLETA.** `SyncJob(comuna, rubro)` idempotente +
  clasificadores (presencia ADR-003, pos_candidate ADR-004, lead_score ADR-008) + `sync_runs`
  + rake tasks (sync/audit/reclassify). **Primer sync real hecho** (Curicó × restaurantes,
  2026-07-07): 20 negocios, 18/20 bien clasificados. Ajuste con evidencia: nueva lista
  `site_builder_domains` (UENI, HorecaQR, Wix… → solo_redes), ver CASES.md. Falso `web_propia`
  del directorio de mall queda como limitación conocida (AUD-008). `rake oteo:reclassify`
  aplica cambios de config sin re-syncar. 121 specs verde.
- **Fase 2 — Las tres vistas: ✅ COMPLETA.** ✅ Tabla filtrable (comuna/presencia/pos/rubro,
  carriles reputación vs. nuevos, Turbo Frame + Pagy), ✅ ficha con guion de venta por estado
  + captura móvil de `pos_status` (Turbo Stream) + historial de `contact_events`, ✅ kanban
  drag&drop (SortableJS), ✅ **mapa Google Maps JS** (marcadores por presencia, infowindow →
  ficha; AUD-002 resuelto → Plan A). 125 specs verde. **Pendiente operativo:** cargar la Maps
  JS key (`GOOGLE_MAPS_JS_API_KEY`); sin ella el mapa muestra fallback. Deploy Kamal: AUD-011.
  Datos para revisar la UI sin API: `rake oteo:demo_data` (solo dev).
- **Fase 3 — Operación: ✅ COMPLETA (falta deploy real).** ✅ Sync programado quincenal
  (`config/recurring.yml`: `SyncAllJob` día 1 y 15; `ExpirePlacesDataJob` semanal), ✅ **página
  de salud** `/salud` (cuota mensual vs cupo, vencidos/expirados, jobs fallidos, últimas
  corridas), ✅ **job de expiración a 30 días** (AUD-012, cumplimiento ToS), ✅ **guiones de
  contacto** por estado en la ficha (plantilla copiable + "Abrir en WhatsApp" con mensaje
  pre-cargado). Config de Kamal + backup + `docs/DEPLOY.md` listos. 138 specs verde.
  ⚠️ **Deploy real pendiente de verificación humana** (AUD-011): necesita el VPS.
- **Fase 4 — Solo con tracción:** verificación HTTP, señal "solo efectivo", producto.

## Cierre de fase — Definition of Done (obligatorio)
Ninguna fase se da por cerrada sin completar, en orden:
1. **Ronda crítica (vista de halcón)** — releer el código de la fase cazando bugs y casos
   borde; corregir los de riesgo real, documentar los diferidos como `AUD-NNN`.
2. **Casos borde → `docs/CASES.md`** — registrar URIs/señales raros (sobre todo tras syncs
   reales) antes de tocar las listas de `config/oteo.yml`.
3. **Deuda → `docs/AUDIT.md`** — todo trade-off aceptado con trabajo futuro obtiene su `AUD-NNN`.
4. **Incidentes → `docs/TROUBLESHOOTING.md`** — toda falla resuelta durante la fase.
5. **Contexto → este `CLAUDE.md` + `README.md`** — roadmap, conteo de specs y comandos, en
   sincronía con el resto de los `.md`.
6. **Verde** — `rspec` + `rubocop` + `brakeman` + `bundler-audit` limpios.
7. **Commit + push.**

## Reglas del repo (SAD §14)
1. El SAD cambia **solo por ADR nuevo o enmienda versionada** (§16), nunca ediciones silenciosas.
2. Todo trade-off "aceptado" que implique trabajo futuro **debe** tener su `AUD-NNN` en AUDIT.md.
3. `docs/CASES.md` es la memoria del clasificador: antes de tocar la lista de dominios de
   `config/oteo.yml`, documentar el caso ahí con su URI real.
4. Prueba de que este archivo funciona: una sesión nueva retoma el proyecto leyendo solo esto.
