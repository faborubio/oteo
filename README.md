<h1 align="center">Oteo</h1>

<p align="center">
  <strong>Dashboard de prospección de negocios locales del Maule sin presencia digital.</strong><br>
  Recorre Google Places por comuna × rubro, clasifica la presencia digital de cada negocio
  y su candidatura a POS, y lo convierte en un pipeline de ventas accionable.
</p>

<p align="center">
  <a href="https://github.com/faborubio/oteo/actions/workflows/ci.yml"><img src="https://github.com/faborubio/oteo/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <img src="https://img.shields.io/badge/Ruby-3.3-CC342D?logo=ruby&logoColor=white" alt="Ruby 3.3">
  <img src="https://img.shields.io/badge/Rails-8.1-CC0000?logo=rubyonrails&logoColor=white" alt="Rails 8.1">
  <img src="https://img.shields.io/badge/PostgreSQL-16-4169E1?logo=postgresql&logoColor=white" alt="PostgreSQL 16">
  <img src="https://img.shields.io/badge/tests-RSpec-brightgreen" alt="RSpec">
</p>

---

## ¿Qué es Oteo?

**Otear** es escudriñar el horizonte desde lo alto en busca de algo. Oteo otea el territorio
comercial del Maule: encuentra negocios con **buena reputación** (muchas reseñas) pero **sin
web propia** — el lead ideal para vender un sitio web — y detecta candidatos para un sistema
POS, un dato que Google no tiene y que se captura en terreno.

El problema que resuelve: prospectar a mano en Google Maps significa abrir ficha por ficha,
verificar si hay web y anotar en una planilla. La señal que convierte —*negocio con reputación
y sin presencia digital*— existe en Places pero **no es filtrable desde Maps**. Oteo la extrae,
la clasifica y la ordena por prioridad de venta.

Es una **herramienta interna de un solo usuario**, construida con disciplina de producto: cada
decisión de arquitectura está documentada como ADR en el [SAD](SAD-Oteo.md), con su contexto y
trade-offs.

## Características

- 🔎 **Sincronización desde Google Places API (New)** con un adapter que aísla al proveedor y
  minimiza costo: todos los campos se piden en el field mask del Text Search, nunca Place
  Details por lugar (**~144 llamadas/mes** vs. ~2.900 del enfoque ingenuo).
- 🏷️ **Clasificación de presencia digital en tres estados** — `sin_presencia` / `solo_redes` /
  `web_propia` — donde redes sociales y agregadores de delivery **no** cuentan como web propia
  (cada estado tiene su guion de venta).
- 🎯 **Candidatura POS híbrida**: heurística automática por rubro + confirmación manual en
  terreno; el dato observado siempre manda sobre el inferido.
- 📈 **Lead score explícito y ajustable**: `log(1 + reseñas) × peso_presencia × bonus_POS`.
  La tabla se ordena por prioridad de prospección.
- 🔁 **Pipeline idempotente**: re-sincronizar nunca duplica filas ni pisa el dato de terreno
  (notas, etapa del pipeline, POS observado).
- 💰 **Costo cero de operación**: corre en un VPS propio dentro del free tier de Places; sin
  Redis ni servicios pagados (Solid Queue/Cache/Cable sobre PostgreSQL).

## Arquitectura

Un pipeline batch simple — **sincronizar → clasificar → persistir** — y tres vistas sobre la
misma tabla `businesses`:

```
  Solid Queue                Google Places API (New)
  SyncJob(comuna, rubro) ──▶  PlacesClient (adapter, field mask mínimo)
                                        │  emite Snapshot normalizado
                                        ▼
                              BusinessClassifier
                              ├─ PresenceClassifier  (ADR-003)
                              ├─ PosCandidateClassifier (ADR-004)
                              └─ LeadScorer          (ADR-008)
                                        │
                                        ▼
                     PostgreSQL: businesses · business_rubros
                               sync_runs · contact_events
                                        │
                 ┌──────────────────────┼──────────────────────┐
                 ▼                      ▼                      ▼
             Tabla filtrable        Mapa (Leaflet)        Kanban CRM
             (Turbo Frames)         por estado            (Turbo Streams)
```

**El dominio no sabe de Google.** `PlacesClient` es un adapter tras una interfaz: los
clasificadores y modelos consumen un `Snapshot` normalizado, no el JSON de Google. Si Places
cambia de versión o se agrega otra fuente, el dominio no se toca. En tests el adapter se
sustituye con WebMock — cero llamadas reales en CI.

## Stack

Ruby 3.3 · Rails 8.1 · PostgreSQL 16 (`jsonb`) · Hotwire (Turbo + Stimulus) · Tailwind CSS ·
Solid Queue/Cache/Cable · Kamal 2 · RSpec · RuboCop (omakase) · Brakeman · bundler-audit.

## Puesta en marcha

### Requisitos
- Ruby 3.3, PostgreSQL 16 corriendo localmente.
- Una API key de Google Places API (New) para sincronizar datos reales (opcional para dev/tests).

### Instalación
```bash
git clone https://github.com/faborubio/oteo.git
cd oteo
bundle install                 # instala gems en vendor/bundle (ver nota abajo)
bin/rails db:create db:migrate

# Usuario único + taxonomías (6 comunas × 8 rubros = 48 combinaciones)
OTEO_ADMIN_EMAIL=tu@correo.cl OTEO_ADMIN_PASSWORD=secreto bin/rails db:seed

bin/dev                        # levanta web + watcher de Tailwind
```

> **Nota:** en este entorno los gems del sistema no son escribibles, así que bundler instala en
> `vendor/bundle` (`.bundle/config`). Consecuencia: usar siempre `bundle exec` (o `bin/*`).

### Variables de entorno
| Variable | Uso |
|---|---|
| `GOOGLE_PLACES_API_KEY` | Autenticación con Places API (restringir por API + IP en producción) |
| `OTEO_ADMIN_EMAIL` / `OTEO_ADMIN_PASSWORD` | Usuario único, usados por el seed |

## Uso

Sincronizar desde Places (requiere `GOOGLE_PLACES_API_KEY`):

```bash
# Sync síncrono de una combinación, ideal para auditar el primer resultado real
bundle exec rake 'oteo:sync_now[curico,restaurantes]'

# Encolar una combinación en Solid Queue
bundle exec rake 'oteo:sync_one[talca,botillerias]'

# Encolar TODAS las combinaciones activas
bundle exec rake oteo:sync_all
```

Cada corrida se audita en `sync_runs` (encontrados / nuevos / actualizados / errores y
**llamadas consumidas** contra la cuota). Si la cuota se agota, el job aborta y alerta — jamás
pasa a facturación.

## Calidad

```bash
bundle exec rspec                 # suite completa (113 ejemplos)
COVERAGE=true bundle exec rspec   # con reporte de cobertura
bundle exec rubocop               # estilo (omakase)
bin/brakeman --no-pager           # análisis de seguridad estático
bin/bundler-audit                 # CVEs en dependencias
```

El CI (GitHub Actions) corre estos cuatro jobs — `scan_ruby`, `scan_js`, `lint`, `test`
(con servicio PostgreSQL)— en cada push y PR.

## Estructura del proyecto

```
app/
  models/         businesses, business_rubros, comunas, rubros, sync_runs, contact_events
  services/       PlacesClient (adapter) · clasificadores · BusinessClassifier (facade)
  jobs/           SyncJob (idempotente)
config/
  oteo.yml        dominios sociales, pesos del lead_score, ventana de retención ToS
docs/
  AUDIT.md        deuda técnica y gates legales (formato AUD-NNN)
  CASES.md        memoria del clasificador: URIs reales y qué se decidió
  TROUBLESHOOTING.md
SAD-Oteo.md       Software Architecture Document — la fuente de verdad
CLAUDE.md         contexto operativo para retomar el proyecto entre sesiones
```

## Roadmap

| Fase | Alcance | Estado |
|---|---|---|
| **0 — Cimientos** | Scaffold, toolkit, auth, modelo de datos, adapter Places, taxonomías, CI | ✅ Completa |
| **1 — Pipeline de datos** | SyncJob idempotente + clasificadores + `sync_runs` | ✅ Completa (falta primer sync real) |
| **2 — Las tres vistas** | Tabla filtrable, ficha + captura móvil de POS, kanban drag&drop | 🟡 Tabla + ficha + kanban listos; mapa y deploy diferidos por gate legal |
| **3 — Operación** | Sync programado quincenal, página de salud, backups probados, guiones | ⬜ |
| **4 — Solo con tracción** | Verificación HTTP de webs, señal "solo efectivo", recordatorios, producto | ⬜ |

## Documentación

- **[SAD-Oteo.md](SAD-Oteo.md)** — arquitectura completa, drivers, NFRs y todos los ADR con
  sus trade-offs. Es la fuente de verdad; el resto de docs deriva de aquí.
- **[CLAUDE.md](CLAUDE.md)** — contexto operativo para retomar el proyecto en una sesión nueva.
- **[docs/AUDIT.md](docs/AUDIT.md)** — deuda técnica explícita y gates legales pendientes.
- **[docs/CASES.md](docs/CASES.md)** — memoria del clasificador de presencia digital.

## Autor

**Fabián Rubio** — Full Stack. Herramienta interna; potencial producto futuro.
