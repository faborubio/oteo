# Software Architecture Document (SAD)
## Oteo — Dashboard de prospección de negocios locales sin presencia digital (Rails 8 + Hotwire + Google Places)

| Campo | Valor |
|---|---|
| Proyecto | Oteo — prospección multi-producto (webs + POS) de negocios del Maule |
| Versión | 1.3.0 |
| Estado | Implementado (Fases 0-3); deploy pendiente (AUD-011) |
| Autor | Fabián Rubio — Full Stack |
| Audiencia | Uso interno (herramienta propia), potencial producto futuro |
| Última revisión | 2026-07-08 |

> **Nota de lectura.** Este SAD describe *por qué* el sistema está construido así, no solo *qué* contiene. Las decisiones se registran como ADRs con su contexto y trade-offs. **Oteo** es el acto de otear: escudriñar el horizonte desde lo alto en busca de algo — desde la *Atalaya* se otea. Aquí se otea el territorio comercial del Maule: recorre Google Places por ciudad × rubro, clasifica la presencia digital de cada negocio (sin web / solo redes / web propia) y su necesidad de POS, y convierte ese registro en un pipeline de ventas accionable (mapa + tabla + kanban). Es una **herramienta interna primero**: su cliente inicial soy yo mismo vendiendo (a) sitios web basados en plantillas por nicho y (b) mi propio sistema POS. Si demuestra valor, el camino a producto (tipo FinderLead, validado en España) queda abierto — pero ninguna decisión de hoy paga el costo de ese futuro por adelantado.

---

## 1. Contexto y objetivos

### 1.1 Problema que resuelve
Prospectar clientes para servicios web y POS en ciudades de región (Talca, Curicó, Constitución, Curepto y alrededores) hoy significa buscar negocio por negocio en Google Maps, abrir cada ficha, verificar si tiene web, anotar en una planilla y perder el hilo del seguimiento. De cada 10 negocios revisados a mano, la mayoría ya tiene web o no califica: tiempo perdido. El dato que convierte — *negocio con buena reputación (muchas reseñas) y sin presencia digital propia* — existe en Google Places pero no es filtrable desde Maps. Y el segundo producto (POS) necesita un dato que Google **no** tiene: qué sistema de venta usa el negocio, lo que exige capturarlo en terreno.

### 1.2 Objetivos (qué consideramos éxito)
- **Cobertura:** ≥ 8 rubros × ≥ 6 comunas del Maule sincronizados, con refresco programado, dentro de la cuota gratuita mensual de Places API.
- **Calidad del lead:** clasificación automática correcta de presencia digital (sin web / solo redes / web propia) verificable contra muestreo manual ≥ 95%.
- **Accionabilidad:** de la apertura del dashboard a una lista priorizada y filtrada de leads contactables en < 30 segundos.
- **Seguimiento:** todo contacto queda registrado (kanban + notas); cero leads "perdidos en el cuaderno".
- **Resultado de negocio (el KPI real):** primeros 3 clientes (web o POS) originados desde la herramienta en los primeros 60 días de uso.

### 1.3 Fuera de alcance
- **Envío automatizado de mensajes** (WhatsApp/email masivo): el contacto es manual y personalizado; la herramienta prepara el argumento, no lo dispara. Evita spam y riesgos de bloqueo de número.
- **Multi-tenant / auth de terceros:** un solo usuario (yo). El modelo de datos no lo impide a futuro, pero no se construye hoy (ver §Nota de lectura).
- **Scraping de Google Maps:** prohibido por diseño (ADR-002).
- **Detección automática del POS instalado:** no existe fuente de datos confiable; se resuelve con heurística + captura manual (ADR-004).

---

## 2. Drivers de arquitectura y atributos de calidad

Prioridades ordenadas. Cuando dos chocan, gana el de más arriba.

| # | Atributo | Por qué prioriza | Cómo se mide |
|---|---|---|---|
| 1 | **Velocidad de entrega** | Es una herramienta interna; cada semana sin usarla es prospección perdida | MVP usable (sync + tabla + filtros) en 1 fin de semana |
| 2 | **Costo cero de operación** | Debe correr en el VPS ya pagado y dentro del free tier de Places | factura mensual Google = $0; sin servicios nuevos pagados |
| 3 | **Cumplimiento de ToS de Google** | Violar los términos de Places arriesga la API key y el proyecto | reglas de caché/retención implementadas (ADR-006) |
| 4 | **Calidad del dato** | Un lead mal clasificado desperdicia una visita/llamada | precisión de clasificación ≥ 95% sobre muestreo |
| 5 | **Simplicidad operativa** | Un solo dev que además vende; el sistema no puede pedir niñera | un deploy (Kamal), una BD, cero microservicios |
| 6 | **Extensibilidad a producto** | FinderLead validó el modelo; la puerta queda abierta | dominio desacoplado de la fuente de datos (ADR-002) |

**Decisión consciente:** Oteo optimiza para *tiempo-a-primer-lead y costo cero*, no para escala. Es un monolito para un usuario. La escala (multi-tenant, colas distribuidas, billing) es un problema que solo existe si el negocio funciona — y ese es exactamente el dato que esta herramienta va a producir.

---

## 3. Restricciones y supuestos

**Restricciones**
- Stack: **Ruby 3.3 · Rails 8 · Hotwire (Turbo + Stimulus) · Tailwind CSS**, mismo patrón de FleetPilot para reutilizar músculo y convenciones (Solid Queue/Cache/Cable database-backed, RSpec, RuboCop, Brakeman, Kamal).
- Base de datos: **PostgreSQL 16** (a diferencia de FleetPilot/MySQL: aquí se quiere `jsonb` para payloads de Places y la opción PostGIS si el filtrado geoespacial crece).
- Presupuesto: **$0 adicionales/mes.** VPS propio existente + cupos gratuitos **por SKU** de Google Places API (desde 2025 Google reemplazó el crédito mensual de US$200 por cupos mensuales por SKU — del orden de 10.000 Essentials / 5.000 Pro / 1.000 Enterprise; **verificar valores vigentes en Fase 0**).
- Fuente de datos: **Google Places API (New)** exclusivamente — Text Search + Place Details con field masks mínimos.

**Supuestos**
- El volumen es pequeño: ~8 rubros × ~6 comunas × ~20-60 resultados ≈ **2.000–5.000 negocios** totales. Cabe en una tabla sin particionar; los jobs de sync corren en minutos.
- Un refresco **quincenal o mensual** por combinación ciudad×rubro es suficiente: los negocios no cambian de web cada semana.
- El campo `websiteUri` de Places es la señal primaria; un URI apuntando a facebook.com/instagram.com/linktr.ee cuenta como "solo redes", no como web propia (ADR-003).
- La captura del dato POS ocurre en terreno o por teléfono; el sistema debe hacerla trivial desde el móvil (1 tap).

---

## 4. Vista general de la arquitectura

### 4.1 Contexto del sistema

```
                    (programado: quincenal, o manual on-demand)
  ┌──────────────────────────────────────────────────────────────────┐
  │  Solid Queue — SyncJob(ciudad, rubro)                            │
  │  ┌──────────────┐  Text Search   ┌──────────────────────────┐    │
  │  │ Google Places │ ◄───────────── │ PlacesClient (adapter,   │    │
  │  │ API (New)     │  Place Details │ field masks mínimos,     │    │
  │  │               │ ─────────────► │ rate-limited, cacheado)  │    │
  │  └──────────────┘                └──────────┬───────────────┘    │
  │                                             ▼                    │
  │                        ┌────────────────────────────────┐        │
  │                        │ Clasificador                   │        │
  │                        │ - presencia digital (ADR-003)  │        │
  │                        │ - heurística POS (ADR-004)     │        │
  │                        │ - lead score (ADR-008)         │        │
  │                        └────────────┬───────────────────┘        │
  │                                     ▼                            │
  │                          PostgreSQL (businesses,                 │
  │                          sync_runs, contact_events)              │
  └─────────────────────────────────┬────────────────────────────────┘
                                    │
             ┌──────────────────────┼──────────────────────┐
             ▼                      ▼                      ▼
      ┌────────────┐        ┌────────────┐         ┌────────────┐
      │ Tabla      │        │ Mapa       │         │ Kanban CRM │
      │ filtrable  │        │ Google     │         │ (Turbo     │
      │ (Turbo     │        │ Maps JS    │         │ Streams,   │
      │ Frames)    │        │ (markers   │         │ drag&drop) │
      │            │        │ por estado)│         │            │
      └────────────┘        └────────────┘         └────────────┘
                     Rails 8 monolito · Hotwire · Kamal → VPS propio
```

### 4.2 Un pipeline, tres vistas
El corazón es un pipeline batch simple: **sincronizar → clasificar → persistir**. Todo lo demás son vistas sobre la misma tabla `businesses`: la **tabla** para filtrar y priorizar, el **mapa** para planificar rutas de visita en terreno, el **kanban** para no perder el hilo del seguimiento. No hay tiempo real ni streams: el dato cambia dos veces al mes (sync) o cuando yo lo edito (captura manual). Turbo Frames/Streams cubren toda la interactividad sin una SPA (ADR-001).

### 4.3 El dominio no sabe de Google
`PlacesClient` es un **adapter tras una interfaz** (mismo principio que ADR-011 de Atalaya): el clasificador y los modelos consumen un `BusinessSnapshot` normalizado, no el JSON de Google. Si mañana se agrega otra fuente (directorios de cámaras de comercio, SII) o Places cambia de versión, el dominio no se toca. En tests, el adapter se sustituye por fixtures grabadas (VCR) — cero llamadas reales en CI.

---

## 5. Decisiones de arquitectura (ADRs)

### ADR-001 — Rails 8 monolito + Hotwire, no SPA
**Contexto:** la herramienta necesita tabla filtrable, mapa y kanban. La tentación es React (experiencia previa del autor); la alternativa es el patrón FleetPilot (monolito + Hotwire).
**Decisión:** **monolito Rails 8 con Hotwire.** Turbo Frames para filtros y paginación, Turbo Streams para el kanban, Stimulus controllers para Leaflet y el drag & drop.
**Razón:** un solo proyecto, un solo deploy, cero CORS/tokens/API versionada. La interactividad requerida (filtros, drag & drop, mapa) está dentro de lo que Hotwire resuelve bien. Reutiliza las convenciones ya dominadas en FleetPilot: el costo de arranque es casi cero.
**Trade-off:** el mapa y el kanban en Stimulus son menos cómodos que en React. Aceptado: son dos controllers acotados, no una app. Si Oteo se vuelve producto multi-usuario, extraer una API desde el monolito es trabajo conocido.

### ADR-002 — Google Places API oficial con adapter, nunca scraping
**Contexto:** el dato vive en Google Maps. Scrapearlo es gratis pero viola los ToS, es frágil (HTML cambia) y arriesga bloqueos. La API oficial tiene free tier mensual y contrato estable.
**Decisión:** **Places API (New)** exclusivamente, con una regla de oro de cuota: **todos los campos se piden en el field mask del propio Text Search** (id, displayName, formattedAddress, location, rating, userRatingCount, websiteUri, nationalPhoneNumber, types, businessStatus) — **nunca** Place Details por cada lugar. El SKU del Text Search se cobra **por búsqueda**, no por lugar devuelto; Details se reserva para refrescos puntuales de registros individuales. El acceso pasa por `PlacesClient`, un adapter que expone `BusinessSnapshot` y esconde el proveedor.
**Razón:** legalidad y estabilidad por sobre el ahorro marginal — y la aritmética manda: pedir `websiteUri`/teléfono eleva la llamada al SKU Enterprise, cuyo cupo gratuito es el más chico (~1.000/mes). Con campos en el Text Search: 48 combinaciones × ~3 páginas ≈ **144 llamadas Enterprise/mes** — holgado. Con Details por lugar: 48 × ~60 ≈ **2.900 llamadas/mes → facturación**. La misma información, 20× el costo. El adapter deja la puerta abierta a fuentes adicionales sin tocar el dominio.
**Trade-off:** dependencia de cuota y de los términos de Google (ver ADR-006, consecuencia directa). Aceptado: es la única fuente viable y el diseño la aísla. El contador de llamadas por SKU en `sync_runs` es obligatorio, no decorativo.

### ADR-003 — Clasificación de presencia digital en tres estados, con redes sociales ≠ web propia
**Contexto:** el campo `websiteUri` de Places viene vacío, con un dominio propio, o con un link a Facebook/Instagram/Linktree/WhatsApp. Para vender sitios web, "tiene link a Instagram" es un lead *mejor* que "no tiene nada" (ya valora la presencia digital) pero distinto de "tiene web propia" (descartado o candidato a rediseño).
**Decisión:** clasificador de tres estados persistido como enum: `sin_presencia` (URI vacío), `solo_redes` (URI matchea lista de dominios sociales: facebook, instagram, linktr.ee, wa.me, tiktok, etc.), `web_propia` (cualquier otro dominio). La lista de dominios sociales vive en configuración, no en código.
**Razón:** el argumento de venta cambia por estado — a `sin_presencia` se le vende visibilidad; a `solo_redes`, profesionalización ("que no dependa del algoritmo de Meta"); a `web_propia`, nada o rediseño. Tres estados = tres guiones de contacto.
**Trade-off:** falsos positivos posibles. Casos borde catalogados y su tratamiento: **acortadores** (bit.ly, cutt.ly) esconden el destino → se resuelve el redirect antes de clasificar; **agregadores de delivery** (PedidosYa, Rappi, UberEats) y catálogos de WhatsApp cuentan como `solo_redes` (presencia en plataforma de terceros, no web propia — y son excelente lead: ya pagan comisión por existir online); **dominios muertos o estacionados** clasificarían como `web_propia` siendo leads → la verificación HTTP los detecta; la verificación misma tiene bordes: sitios que bloquean HEAD (405 → reintentar con GET) y anti-bot que devuelve 403 con el sitio vivo (403 ≠ caído; solo un fallo DNS/timeout/5xx marca `web_caida`). Lista de dominios y reglas en configuración, no en código.

### ADR-004 — Columna POS híbrida: heurística automática por rubro + confirmación manual en terreno
**Contexto:** Google no expone qué sistema de venta usa un negocio. El segundo producto del autor (POS propio, en desarrollo) necesita saber quién es candidato. Dos fuentes imperfectas: el **rubro** (restaurantes, minimarkets, botillerías, farmacias, food trucks son candidatos naturales) y la **observación directa** (visita/llamada).
**Decisión:** dos campos separados: `pos_candidate` (boolean, **calculado** por el clasificador desde los `types` de Places contra una lista configurable de rubros-objetivo) y `pos_status` (enum **manual**: `desconocido` / `sin_sistema` / `caja_tradicional` / `competidor` / `usa_el_nuestro`, con campo libre para anotar cuál competidor — Bsale, Toteat, etc.). La heurística pre-filtra; el dato manual manda: si `pos_status` ≠ `desconocido`, la UI muestra el manual.
**Razón:** separar el dato inferido del observado evita que la heurística "contamine" la verdad de terreno, y hace el pipeline honesto: la columna calculada dirige *a quién preguntar*, la manual registra *qué se respondió*. La captura manual es 1 tap desde la ficha en móvil.
**Trade-off:** la columna empieza mayormente en `desconocido` y se llena con el uso. Aceptado: es exactamente el trabajo de prospección que la herramienta organiza. Señal futura (backlog): detectar "solo efectivo" en el texto de reseñas — lead calificadísimo — cuando se justifique el costo del SKU de reviews.

### ADR-005 — Solid Queue para el sync, sin Redis ni infraestructura nueva
**Contexto:** el sync ciudad×rubro debe correr programado (quincenal) y on-demand, con reintentos. FleetPilot ya usa Solid Queue (database-backed, Rails 8 default).
**Decisión:** **Solid Queue** con `recurring.yml` para el calendario y un `SyncJob(comuna, rubro)` idempotente por combinación. Concurrencia limitada (1-2 workers) para respetar el rate limit de Places.
**Razón:** cero infraestructura adicional (ni Redis ni Sidekiq); los jobs viven en la misma BD respaldada; el patrón ya está dominado. Para ~50 combinaciones/quincena es sobredimensionado incluso.
**Trade-off:** ninguno relevante a esta escala.

### ADR-006 — Cumplimiento de ToS de Places: `place_id` como única clave persistente de largo plazo, retención limitada del resto
**Contexto:** los términos de Google Places restringen el almacenamiento de datos de la API: el `place_id` puede guardarse indefinidamente, pero el resto del contenido (nombre, rating, teléfono, etc.) tiene ventanas de caché limitadas (del orden de 30 días) y debe refrescarse, no atesorarse.
**Decisión:** el modelo persiste **`place_id` como clave estable** + los campos de Places con `synced_at`; la UI marca como **"dato vencido"** todo registro cuyo sync supere la ventana de retención y el job de refresco los prioriza. Los datos **propios** (pos_status, notas, estado kanban, eventos de contacto) son nuestros y se retienen sin límite, colgando del `place_id`. Antes de implementar, **verificar la versión vigente de los ToS** (cambian) y ajustar la ventana en configuración.
**Razón:** cumplir el contrato que hace viable la fuente (driver #3). Separar "dato de Google (refrescable, perecible)" de "dato mío (permanente)" en el modelo hace el cumplimiento estructural, no disciplinario.
**Trade-off:** llamadas de refresco periódicas (dentro del free tier a este volumen) y una UI que debe tolerar datos marcados como vencidos. Aceptado: es el costo de existir legalmente.
**Enmienda (v1.3.0, 2026-07-08):** ToS verificados (AUD-001): caché de Places = **30 días**, `place_id` exento (indefinido). Implementado en Fase 3 como **`ExpirePlacesDataJob`** (recurrente semanal): nulifica los campos perecibles de Places de registros con `synced_at` > 30 días (flag `places_expired`), conservando `place_id`, identificación mínima (nombre/dirección) y todo el dato propio; el sync repuebla y resetea el flag. Interpretación de zona gris (herramienta interna): se conserva nombre/dirección como identificación mínima del lead operativo. La página de salud (`/salud`) muestra "vencidos" y "expirados".

### ADR-007 — Mapa con Leaflet + OpenStreetMap vía Stimulus, no Google Maps embebido
**Contexto:** el mapa sirve para planificar rutas de visita en terreno y ver densidad de leads por zona. Google Maps JS API consume cuota; Leaflet + OSM es gratis.
**Decisión:** **Leaflet** con tiles de OpenStreetMap, montado por un Stimulus controller que recibe los negocios filtrados como JSON embebido. Marcadores coloreados por estado (`sin_presencia` rojo, `solo_redes` naranjo, `web_propia` gris; badge POS aparte). Click en marcador → Turbo Frame con la ficha.
**Razón:** cero costo, cero cuota, y la coordenada viene de Places así que la precisión es la misma. Leaflet es liviano y suficiente para < 5.000 puntos.
**Trade-off / ⚠️ riesgo legal abierto:** los términos de Google Maps Platform han prohibido históricamente usar datos de los servicios (incluido Places) **sobre un mapa que no sea de Google** ("No Use With Non-Google Maps"). Plotear resultados de Places API en Leaflet/OSM puede violar esa cláusula. **Gate de Fase 0: verificar los términos vigentes antes de implementar el mapa.** Plan B si la restricción sigue activa: (a) **Google Maps JS API** — su cupo gratuito de mapas dinámicos cubre de sobra el volumen de un solo usuario, y el Stimulus controller cambia de librería sin tocar el resto; o (b) mapa Leaflet solo con **datos propios** (negocios de origen manual, ADR-012). La decisión queda condicionada, no asumida.
**Enmienda (v1.3.0, 2026-07-08):** gate verificado (AUD-002, 2026-07-07): la cláusula "No Use With Non-Google Maps" **sigue vigente** → plotear Places sobre Leaflet/OSM viola los ToS. **Decisión revisada: Plan A — Google Maps JS API.** Implementado en Fase 2 (`map_controller.js`): marcadores por `digital_presence`, infowindow → ficha, JSON acotado al filtro (NFR §9). **Leaflet queda descartado.** Key browser restringida por HTTP referrer (`GOOGLE_MAPS_JS_API_KEY`). El link "Cómo llegar" de la ficha es un enlace normal a Google Maps (ToS-safe).

### ADR-008 — Lead score explícito y simple: reputación × ausencia de presencia
**Contexto:** con 2.000+ negocios, el orden de la tabla ES la estrategia de prospección. El insight de negocio: *muchas reseñas + sin web propia = negocio al que le va bien y está perdiendo clientes digitales* — el argumento de venta se escribe solo.
**Decisión:** `lead_score` calculado y persistido en el clasificador: función simple y **legible** (ej. `log(1+userRatingCount) × peso_presencia × bonus_pos_candidate`, pesos en configuración). La tabla ordena por score descendente por defecto.
**Razón:** un score explícito y ajustable convierte la base en una cola de trabajo priorizada. Se prefiere una fórmula que el autor pueda explicar en una frase por sobre cualquier sofisticación: la validación del score es empírica (¿los de arriba convierten?) y los pesos se ajustan con esa evidencia.
**Trade-off:** el score inicial es una hipótesis. Aceptado y deseado: la herramienta existe para producir el dato que lo calibre. Caso borde corregido: con `userRatingCount = 0`, `log(1+0) = 0` entierra al negocio recién abierto — que es candidato POS perfecto (aún no compró sistema). Los sin-reseñas no compiten en el mismo ranking: van a una **vista aparte "nuevos/sin reputación"**, filtrable por rubro POS, en vez de perderse al fondo de la tabla.

### ADR-009 — Kanban CRM embebido con Turbo Streams, no herramienta externa
**Contexto:** el seguimiento podría vivir en Trello/Notion/planilla, pero eso rompe el flujo (dos herramientas) y pierde el vínculo con el dato del negocio.
**Decisión:** kanban propio: columnas `nuevo → contactado → propuesta → cerrado / descartado` sobre el campo `pipeline_stage`, drag & drop con Stimulus (SortableJS) y persistencia por Turbo Streams. Cada movimiento y cada nota generan un `contact_event` (historial completo por negocio, con producto asociado: web / POS / ambos).
**Razón:** el CRM al lado del dato — teléfono, score, mapa y guion de venta en la misma ficha — es la diferencia entre una lista y un pipeline. FinderLead validó exactamente este acoplamiento (buscador + kanban).
**Trade-off:** funcionalidad CRM mínima (sin recordatorios ni email). Suficiente para un usuario; el backlog anota recordatorios simples vía job diario si duele.

### ADR-010 — Deploy con Kamal 2 al VPS propio + backups pg_dump programados
**Contexto:** existe un VPS ya pagado; Railway/Render cobrarían por lo mismo. Kamal es el camino oficial Rails 8 y ya se usó en FleetPilot.
**Decisión:** **Kamal 2** (Docker) al VPS, con Postgres en contenedor con volumen persistente, TLS vía kamal-proxy/Let's Encrypt, y **cron diario de `pg_dump`** comprimido enviado fuera del VPS (bucket externo o segundo destino). Restauración documentada y **probada** una vez.
**Razón:** costo cero marginal, un comando de deploy, y el dato propio (pipeline, notas, pos_status) es lo único irreemplazable del sistema — los datos de Google se re-sincronizan, mis notas no.
**Trade-off:** administrar el servidor es responsabilidad propia. Aceptado: es experiencia vendible y el patrón ya se domina.

### ADR-011 — El corte de ~60 resultados y el sesgo de prominencia: subdividir consultas donde importe
**Contexto:** Text Search devuelve un máximo de ~60 resultados (3 páginas) **ordenados por prominencia**. La ironía es estructural: los leads objetivo (negocios sin presencia digital) son precisamente los **menos prominentes** — los últimos del ranking o directamente fuera del corte. Sin corrección, la herramienta vería sistemáticamente menos a quienes más quiere encontrar.
**Decisión:** tratar la cobertura como configuración por combinación: (a) en comunas chicas (Curepto, Constitución) el corte rara vez se alcanza — sin acción; (b) donde una combinación devuelva 60 resultados (señal de corte), **subdividir la consulta** — por sector/barrio ("restaurantes en Curicó centro", "… sector Rauquén") o por sinónimos del rubro ("picada", "cocinería", "fuente de soda") — registrando cada sub-consulta en `sync_runs`; (c) aceptar y **documentar el sesgo residual**: Oteo complementa, no reemplaza, el ojo en terreno (ADR-012 captura lo que Google no muestra).
**Razón:** el costo marginal es bajo (cada sub-consulta son ≤3 llamadas más) y se paga solo donde el corte se detecta de verdad, no preventivamente en todas partes.
**Trade-off:** más combinaciones que mantener en la taxonomía y solapamiento entre sub-consultas (el upsert por `place_id` lo absorbe). Un grid de Nearby Search exhaustivo queda en backlog: sobredimensionado para 6 comunas.

### ADR-012 — Negocios de origen manual: Google no es el censo
**Contexto:** en pueblos chicos, el mejor lead puede **no tener ficha en Google Maps** — invisible para Places. El modelo v1.0.0 usaba `place_id` como clave única NOT NULL: imposible registrar en terreno un negocio que Google no conoce. Justo el lead más virgen (sin presencia digital *ni siquiera en Maps*) no cabía en la herramienta.
**Decisión:** campo `source` (enum: `places` / `manual`) y **`place_id` nullable** con índice único parcial (`WHERE place_id IS NOT NULL`). Alta manual desde el móvil con lo mínimo (nombre, comuna, rubro, teléfono opcional, pin en el mapa o dirección); los registros manuales no participan del sync ni de la ventana ToS (son 100% dato propio, retención ilimitada) y sí participan de score (con reputación desconocida → vista "nuevos"), kanban y mapa. Si el negocio aparece después en Places, se **vincula** (se le asigna el place_id) conservando historial.
**Razón:** el terreno es una fuente de datos de primera clase, no una excepción. Además resuelve el plan B del mapa (ADR-007): los datos manuales pueden plotear en cualquier mapa sin restricción de ToS.
**Trade-off:** dos orígenes con reglas distintas de retención y refresco — el campo `source` hace la distinción explícita en cada regla.

### ADR-013 — Ciclo de vida del place: ids obsoletos, cierres, duplicados y multi-rubro
**Contexto:** cuatro realidades de Places que el diseño v1.0.0 ignoraba: (1) los `place_id` **caducan o cambian** (Google recomienda refrescarlos; un negocio re-registrado obtiene id nuevo → riesgo de fila duplicada con las notas colgando de la vieja); (2) los negocios **cierran** (`businessStatus`: CLOSED_TEMPORARILY / CLOSED_PERMANENTLY) — visitar uno cerrado es el desperdicio que la herramienta existe para evitar; (3) Google mismo tiene **fichas duplicadas**; (4) un negocio real aparece en **varias búsquedas** (minimarket-botillería) y el campo `rubro` único se pisotearía en cada sync (flapping).
**Decisión:** (1) el refresco maneja `NOT_FOUND`/id renovado: se actualiza el `place_id` conservando la fila y su historial; si aparece id nuevo con nombre+ubicación ≈ iguales a una fila existente, se propone **merge** (heurística: distancia < 50 m + teléfono o nombre normalizado igual) con confirmación manual — nunca merge automático destructivo. (2) `CLOSED_PERMANENTLY` → estado `archivado` automático + `contact_event` de sistema; su tarjeta sale del kanban activo (no se borra: el historial es evidencia de mercado). `CLOSED_TEMPORARILY` se muestra con badge y se excluye de rutas de visita. (3) los duplicados de Google se detectan con la misma heurística de merge. (4) `rubro` deja de ser columna: tabla **`business_rubros`** (n:m) — cada sync **agrega** el rubro por el que encontró al negocio, nunca reemplaza; la comuna se asigna desde la **consulta que lo encontró** (no parseando la dirección, que es frágil en límites comunales).
**Razón:** el activo del sistema es el historial propio colgado de cada negocio; todo el ADR se reduce a una regla: **los eventos de Google mueven estados, jamás destruyen datos propios.**
**Trade-off:** lógica de merge y una tabla más. Aceptado: es la diferencia entre una base que se degrada con cada sync y una que mejora.

---

## 6. Modelo de datos y almacenamiento

- **`businesses`** — el registro central. `source` (enum `places`/`manual`, ADR-012), `place_id` (**nullable**, índice único parcial; clave estable ADR-006), datos de Places (`name`, `address`, `lat`, `lng`, `phone`, `rating`, `user_rating_count`, `website_uri`, `types jsonb`, `business_status`, `synced_at`, `places_expired` bool — flag de expiración ToS, ADR-006/enmienda), clasificación (`digital_presence` enum, `pos_candidate` bool, `lead_score`), datos propios (`pos_status` enum, `pos_vendor`, `pipeline_stage` enum — incluye `archivado`, ADR-013 —, `comuna` asignada desde la consulta de origen).
- **`business_rubros`** — n:m negocio↔rubro (ADR-013): cada sync agrega el rubro por el que lo encontró; un negocio puede ser minimarket *y* botillería sin flapping.
- **`sync_runs`** — auditoría de cada SyncJob: comuna, rubro, timestamps, resultados (encontrados/nuevos/actualizados/errores), costo estimado en llamadas. Es el tablero de salud de la cuota.
- **`contact_events`** — historial por negocio: tipo (llamada/visita/whatsapp/email/nota/cambio de etapa), producto (web/pos/ambos), texto libre, timestamp. Inmutables, append-only.
- **`taxonomies`** (configuración en BD o YAML): comunas objetivo, rubros objetivo con su query de Text Search y flag `pos_target`, dominios considerados "redes sociales", pesos del lead_score, ventana de retención ToS.

**Retención:** datos de Places se refrescan por ventana (ADR-006); `contact_events` y campos propios, para siempre. A este volumen (miles de filas) no hay particionado ni archivado: una BD, índices en (`comuna`, `rubro`), (`digital_presence`), (`lead_score`), y listo.

---

## 7. Flujo de datos end-to-end

1. **Programación:** Solid Queue recurring dispara `SyncJob(comuna, rubro)` según calendario quincenal (o botón "sincronizar ahora" en la UI).
2. **Búsqueda:** el job pide a `PlacesClient` un Text Search `"{rubro} en {comuna}, Chile"` paginado; por cada resultado obtiene el detalle con field mask mínimo (ADR-002).
3. **Normalización:** el adapter emite `BusinessSnapshot`; el job hace upsert por `place_id` y estampa `synced_at`.
4. **Clasificación:** para cada snapshot corre el clasificador — presencia digital (ADR-003), `pos_candidate` (ADR-004), `lead_score` (ADR-008). Los campos manuales (`pos_status`, `pipeline_stage`, notas) **nunca** se tocan en el sync.
5. **Registro:** el `sync_run` cierra con sus contadores; si Places devolvió errores/cuota, el job reintenta con backoff y lo deja anotado.
6. **Uso:** en el dashboard filtro (comuna=Curicó, presencia=solo_redes, pos_candidate=sí, orden=score), reviso el mapa para armar la ruta del día, y desde el móvil en terreno: 1 tap para registrar `pos_status` y mover la tarjeta en el kanban. Cada acción → `contact_event`.

---

## 8. Resiliencia, seguridad y observabilidad

**Resiliencia**
- Jobs idempotentes por (`comuna`, `rubro`) con upsert por `place_id`: re-ejecutar nunca duplica.
- Retry con backoff en errores de API; respeto de rate limits con throttle en el adapter; si la cuota mensual se acerca al límite, el job aborta y alerta (el driver #2 manda: jamás pasar a facturación).
- Backup diario `pg_dump` fuera del VPS + restauración probada (ADR-010). El dato propio es el activo.

**Seguridad**
- Un solo usuario: autenticación nativa Rails 8 (patrón FleetPilot), sesión sobre TLS.
- **API key de Places restringida** (por API y por IP del VPS) y fuera del repo (credentials/ENV). Brakeman + bundler-audit en CI, como en FleetPilot.
- Datos personales mínimos: solo información pública de negocios + mis notas. Sin datos de consumidores.

**Observabilidad**
- `sync_runs` como tablero primario: última corrida por combinación, errores, llamadas consumidas vs cuota estimada del mes.
- Logs estructurados de Rails; a esta escala no se monta stack de métricas — el "health check" es una página interna con: cuota usada, combinaciones vencidas (ADR-006), jobs fallidos.

---

## 9. Performance y escalabilidad (NFRs, medidos)

| Métrica | Objetivo |
|---|---|
| Sync completo (todas las combinaciones) | < 30 min, dentro de rate limits |
| Consumo mensual Places API | ≤ 70% del cupo gratuito del SKU más restrictivo (Enterprise ≈ 1.000 llamadas/mes; con ADR-002 el uso proyectado es ~150) |
| Carga de tabla filtrada (2.000+ filas, paginada) | < 500 ms por página |
| Render del mapa con todos los leads de una comuna | < 2 s |
| Registro de dato en terreno (tap → persistido) | < 1 s percibido (Turbo Stream) |
| Precisión clasificación presencia digital | ≥ 95% vs muestreo manual (n=50) |

**Tácticas:** field masks mínimos y paginación server-side (el costo de Places se controla en el adapter, no después); índices sobre los filtros reales; JSON del mapa acotado al filtro activo — nunca "todos los negocios" de una vez.

---

## 10. Estrategia de testing

| Nivel | Herramienta | Qué cubre |
|---|---|---|
| Unit | RSpec | clasificador (presencia digital, pos_candidate, lead_score) — la lógica que define la calidad del lead |
| Adapter | RSpec + VCR/WebMock | `PlacesClient` contra respuestas grabadas: field masks, paginación, errores de cuota, mapeo a snapshot |
| Jobs | RSpec | idempotencia del upsert, respeto de campos manuales, contadores de sync_run |
| Sistema | Capybara + Cuprite | filtrar tabla, mover tarjeta en kanban, registrar pos_status desde ficha |
| Datos | rake task de auditoría | muestreo aleatorio de 50 negocios → verificación manual de clasificación (alimenta el NFR de precisión) |

**Reglas de oro:** el clasificador se testea con casos reales chilenos (linktr.ee, wa.me, dominios .cl caídos); el adapter jamás llama a Google en CI; la idempotencia del sync es un test, no una esperanza.

---

## 11. CI/CD e infraestructura

```
install → rubocop → brakeman → bundler-audit → rspec (unit + adapter + jobs)
        → system tests → build imagen Docker → kamal deploy (VPS) → smoke (health interno)
```
- GitHub Actions, mismo pipeline base que FleetPilot.
- Kamal 2 con secrets vía `.kamal/secrets`; Postgres con volumen + cron de backup en el host.
- Un ambiente (producción personal). Sin staging: el riesgo lo cubren los tests y el rollback de Kamal.

---

## 12. Riesgos y mitigaciones

| Riesgo | Impacto | Mitigación |
|---|---|---|
| Datos de Places sobre mapa no-Google viola ToS | Alto | Gate de verificación en Fase 0; plan B Google Maps JS o mapa solo-manuales (ADR-007/012) |
| Sesgo de prominencia: los mejores leads quedan fuera del corte de 60 | Alto | Detección del corte + subdivisión de consultas por sector/sinónimo (ADR-011); alta manual en terreno (ADR-012) |
| Cambio de precios/ToS de Places | Alto | Adapter aísla la fuente (ADR-002); monitor de cuota con margen 30% (NFR); ventana de retención configurable (ADR-006) |
| Señal móvil pobre en terreno rural → captura falla en silencio | Medio | Feedback explícito de error en cada acción Turbo (nunca fallo mudo); la captura es 1 campo, reintentable; PWA/offline queda en backlog consciente |
| Clasificación errónea → visitas desperdiciadas | Medio | Lista de dominios sociales configurable + verificación HTTP opcional (ADR-003); auditoría por muestreo (§10) |
| Columna POS se queda en `desconocido` (nadie la llena) | Medio | Captura de 1 tap desde móvil (ADR-004); el kanban obliga a pasar por la ficha |
| Cuota gratuita insuficiente al crecer comunas/rubros | Medio | sync_runs contabiliza llamadas; frecuencia y cobertura son configuración, no código |
| VPS se cae / disco muere | Medio | Backup diario externo probado (ADR-010); re-sync reconstruye lo de Google |
| La herramienta se construye pero no se usa (riesgo real nº1) | Alto | El roadmap exige usarla en terreno desde la Fase 2; el KPI es clientes, no features (§1.2) |
| Tentación de convertirla en producto antes de validarla | Medio | §Nota de lectura: ninguna decisión paga el multi-tenant por adelantado; primero 3 clientes propios |

---

## 13. Roadmap por fases

**Fase 0 — Cimientos (día 1).** **Gates legales primero:** verificar ToS vigentes de retención (ADR-006), la cláusula de mapas no-Google (ADR-007) y los cupos por SKU reales (ADR-002) — 30 minutos que condicionan dos ADRs. Luego `rails new` con el toolkit FleetPilot (RSpec, RuboCop, Brakeman, CI), modelos + migraciones (con `source` y `business_rubros` desde el día 1 — migrar claves después duele), taxonomías seed (6 comunas × 8 rubros), API key restringida, `PlacesClient` con VCR.

**Fase 1 — Pipeline de datos (día 2).** SyncJob idempotente + clasificador (presencia, pos_candidate, score) + sync_runs. Correr el primer sync real: **Curicó × restaurantes**. Auditar 20 resultados a mano → ajustar lista de dominios sociales.

**Fase 2 — Las tres vistas (fin de semana 2).** Tabla filtrable (Turbo Frames) + ficha de negocio + captura móvil de `pos_status` + kanban (Turbo Streams + SortableJS) + mapa Leaflet. **Deploy con Kamal y salir a terreno con la lista de Curicó.**

**Fase 3 — Operación (semanas 3–4).** Sync programado quincenal, página de salud (cuota/vencidos/jobs), backups probados, guiones de contacto por estado de presencia (texto plantilla en la ficha). Ajustar lead_score con la evidencia de los primeros contactos.

**Fase 4 — Solo si hay tracción (backlog).** Verificación HTTP de webs, señal "solo efectivo" en reseñas, recordatorios de seguimiento, export CSV, y — únicamente con ≥ 3 clientes cerrados — evaluar el camino a producto (multi-tenant, billing con pasarela chilena).

Cada fase entrega algo usable. La Fase 2 termina con prospección real en la calle, no con una demo.

---

## 14. Documentación viva

El SAD define el *diseño*; el propósito de los documentos compañeros es **no perder contexto entre sesiones** — de trabajo propio y de trabajo asistido por IA. Convención heredada de los demás repos, simplificada para un proyecto de un solo dev:

| Documento | Qué registra | Cuándo se actualiza |
|---|---|---|
| **`CLAUDE.md`** (raíz) | El contexto operativo para retomar: qué es el proyecto, convenciones, comandos (setup, test, deploy, sync manual), estado actual del roadmap y qué sigue. Es lo primero que lee una sesión nueva — humana o IA | Al cerrar cada sesión de trabajo que cambió el estado del proyecto |
| **`docs/AUDIT.md`** | Deuda técnica explícita y atajos conscientes con su plan de pago (formato `AUD-NNN`). Los gates legales de Fase 0 (ToS retención, ToS mapa, cupos por SKU) son la primera entrada, con veredicto y fecha | Cada vez que se acepta un atajo o se paga uno |
| **`docs/CASES.md`** | Casos reales de clasificación: URIs raros de producción (acortadores nuevos, agregadores no listados, menús en Canva) y qué se decidió. Alimenta la lista configurable del ADR-003 y el test suite | Cada sync que produzca un caso no cubierto |
| **`docs/TROUBLESHOOTING.md`** | Síntoma → causa → fix de todo incidente: cuota agotada, 429 de Places, place_id NOT_FOUND masivos, jobs colgados, restauración de backup. Las fallas con impacto real (ej. sync que pisó datos manuales) se registran aquí mismo con una entrada más profunda: qué pasó, por qué, y qué cambió para que no se repita | Cada incidente resuelto |

**Reglas:** (1) el SAD solo cambia por ADR nuevo o enmienda versionada en §16 — nunca ediciones silenciosas; (2) todo trade-off "aceptado" en un ADR que implique trabajo futuro **debe** tener su `AUD-NNN` — un trade-off sin entrada en AUDIT es deuda invisible; (3) `CASES.md` es la memoria del clasificador: antes de tocar la lista de dominios, el caso se documenta ahí con su URI real; (4) la prueba de que `CLAUDE.md` funciona: una sesión nueva debe poder retomar el proyecto sin releer el historial de chats.

---

## 15. Glosario rápido
- **Lead:** negocio candidato a comprar (web, POS o ambos).
- **Presencia digital:** clasificación sin_presencia / solo_redes / web_propia (ADR-003).
- **pos_candidate vs pos_status:** lo que la heurística infiere vs lo que se observó en terreno (ADR-004).
- **Lead score:** prioridad calculada = reputación × ausencia de presencia (ADR-008).
- **Field mask:** lista explícita de campos pedidos a Places; determina el costo de cada llamada.
- **Upsert:** insertar o actualizar por clave única (`place_id`) — base de la idempotencia del sync.
- **ToS:** Terms of Service; en Places, gobiernan qué se puede almacenar y por cuánto tiempo (ADR-006).

---

## 16. Historial de revisiones

| Versión | Fecha | Cambios |
|---|---|---|
| 1.0.0 | 2026-07-04 | Baseline. Monolito Rails 8 + Hotwire (ADR-001), Places API con adapter y field masks (ADR-002), clasificación de presencia en 3 estados (ADR-003), columna POS híbrida heurística+manual (ADR-004), Solid Queue (ADR-005), cumplimiento ToS con place_id estable (ADR-006), mapa Leaflet/OSM (ADR-007), lead score explícito (ADR-008), kanban CRM embebido (ADR-009), Kamal a VPS propio + backups (ADR-010). Drivers, NFRs, riesgos y roadmap de 4 fases orientado a terreno. |
| 1.1.0 | 2026-07-04 | Ronda crítica (vista de halcón). **Correcciones graves:** ADR-002 reescrito — campos vía Text Search (SKU por búsqueda) en vez de Details por lugar: 144 vs ~2.900 llamadas Enterprise/mes; supuesto de free tier corregido a cupos por SKU (post-2025). ADR-007 — riesgo legal abierto: datos de Places sobre mapa no-Google puede violar ToS; gate en Fase 0 + plan B (Google Maps JS / solo-manuales). **ADRs nuevos:** ADR-011 corte de ~60 resultados y sesgo de prominencia (subdivisión de consultas); ADR-012 negocios de origen manual (`source`, `place_id` nullable — Google no es el censo); ADR-013 ciclo de vida del place (ids obsoletos con merge asistido, cierres → archivado no destructivo, duplicados, `business_rubros` n:m, comuna desde la consulta de origen). **Bordes menores:** clasificador (acortadores, agregadores de delivery, dominios muertos, HEAD→GET, 403≠caído), carril aparte para negocios sin reseñas (ADR-008), riesgo de captura en terreno con señal pobre, gates legales al inicio de Fase 0. |
| 1.1.1 | 2026-07-04 | §14 **Documentación viva**: se formaliza el ecosistema `docs/` (AUDIT.md con formato AUD-NNN, CASES.md como memoria del clasificador, TROUBLESHOOTING.md, POSTMORTEMS.md) siguiendo la convención de los demás repos. Reglas: el SAD cambia solo por ADR/enmienda versionada; todo trade-off aceptado exige su AUD-NNN; los gates legales de Fase 0 son la primera entrada del AUDIT. Glosario e historial renumerados a §15/§16. |
| 1.1.2 | 2026-07-04 | §14 simplificada para un solo dev: POSTMORTEMS.md se fusiona en TROUBLESHOOTING.md (las fallas con impacto son una entrada profunda del mismo archivo); se agrega **`CLAUDE.md`** en la raíz como documento de contexto entre sesiones (humanas o IA) — propósito rector de toda la sección: no perder contexto entre sesiones. Regla 4: una sesión nueva debe poder retomar el proyecto leyendo solo CLAUDE.md. |
| 1.2.0 | 2026-07-04 | **Renombre: Catastro → Oteo.** Motivos: colisión con empresa chilena existente (Catastro Nacional, consultora minera con software propio), término genérico/descriptivo difícil de proteger como marca, y fuerte asociación con registros estatales (SII, Bienes Nacionales). "Oteo" verificado sin conflictos comerciales en Chile (búsqueda web); **pendiente como gate de Fase 0 en AUDIT:** confirmar dominio en nic.cl y marcas en INAPI (clases 9/42). La metáfora rectora se actualiza: desde la Atalaya se otea. |
| 1.3.0 | 2026-07-08 | **Enmienda tras implementar Fases 0-3 con datos reales.** Gates legales verificados (2026-07-07): AUD-001 caché=30 días; AUD-002 "No Use With Non-Google Maps" vigente; AUD-003 cupos por SKU (Enterprise 1.000/mes, uso ~144); AUD-004 marca "Oteo" libre. **ADR-007 enmendado:** Leaflet descartado → **Google Maps JS API** (Plan A) por el gate AUD-002. **ADR-006 enmendado:** `ExpirePlacesDataJob` + flag `places_expired` implementan el borrado a 30 días (AUD-012). §4.1 y §6 actualizados. Estado del proyecto: Fases 0-3 ✅ (sync real de 12 comunas, 2257 negocios; clasificador calibrado con `site_builder_domains`); **pendiente: deploy real (AUD-011)**. El detalle operativo vive en CLAUDE.md y docs/. |

---

*Fin del documento. SAD vivo: cada decisión futura se agrega como un ADR nuevo con su contexto y trade-offs. Una arquitectura no se documenta una vez; se mantiene.*
