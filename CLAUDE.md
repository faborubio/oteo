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
| Seguridad | `bin/brakeman --no-pager` · `bin/bundler-audit` |
| Servidor dev | `bin/dev` (web + watcher de Tailwind) |
| Consola | `bin/rails console` |
| Migrar | `bin/rails db:migrate` |
| Seed (idempotente) | `bin/rails db:seed` |
| Deploy | `kamal deploy` (Fase 2+) |

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
  - ⚠️ **Gates legales pendientes de verificación humana** — ver [docs/AUDIT.md](docs/AUDIT.md)
    AUD-001/002/003/004. Condicionan el mapa (ADR-007) y la config de cuota antes de Fase 2.
- **Fase 1 — Pipeline de datos: siguiente.** `SyncJob(comuna, rubro)` idempotente +
  clasificador (presencia ADR-003, pos_candidate ADR-004, lead_score ADR-008) + `sync_runs`.
  Primer sync real: **Curicó × restaurantes**; auditar 20 resultados a mano.
- **Fase 2 — Las tres vistas:** tabla filtrable, ficha + captura móvil de `pos_status`,
  kanban (Turbo Streams + SortableJS), mapa Leaflet. Deploy Kamal y salir a terreno.
- **Fase 3 — Operación:** sync quincenal, página de salud, backups probados, guiones.
- **Fase 4 — Solo con tracción:** verificación HTTP, señal "solo efectivo", producto.

## Reglas del repo (SAD §14)
1. El SAD cambia **solo por ADR nuevo o enmienda versionada** (§16), nunca ediciones silenciosas.
2. Todo trade-off "aceptado" que implique trabajo futuro **debe** tener su `AUD-NNN` en AUDIT.md.
3. `docs/CASES.md` es la memoria del clasificador: antes de tocar la lista de dominios de
   `config/oteo.yml`, documentar el caso ahí con su URI real.
4. Prueba de que este archivo funciona: una sesión nueva retoma el proyecto leyendo solo esto.
