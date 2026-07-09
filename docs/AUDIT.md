# AUDIT.md — Deuda técnica y atajos conscientes

> Formato `AUD-NNN`. Todo trade-off "aceptado" en un ADR que implique trabajo futuro tiene
> su entrada aquí (SAD §14, regla 2). Un trade-off sin AUD es deuda invisible.
> Estados: 🔴 abierto · 🟡 en curso · 🟢 pagado/verificado.

---

## Gates legales de Fase 0 (bloquean decisiones de arquitectura — verificación humana)

> ⚠️ **Investigación técnica (2026-07-07), no asesoría legal.** Los ToS de Google cambian y su
> interpretación es materia de abogado. Fuentes: Places API Policies y Google Maps Platform
> Service Specific Terms (developers.google.com / cloud.google.com), consultados el 2026-07-07.

### AUD-001 — ToS de retención de datos de Places (ADR-006) 🟢 verificado (con acción)
**Contexto:** el modelo asume que `place_id` se guarda indefinidamente y el resto se refresca
dentro de una ventana (`places_retention_days: 30`).
**Veredicto (2026-07-07):** **Confirmado.** El `place_id` está **exento** de las restricciones
de caché → se puede guardar **indefinidamente**. El resto del contenido de Places (incluidas
lat/lng) se puede cachear **máximo 30 días calendario consecutivos**, tras lo cual **hay que
borrarlo** (no solo marcarlo vencido). `places_retention_days: 30` es correcto.
**Acción pendiente (Fase 3):** el sync quincenal refresca lo que reaparece, pero un negocio
que sale de los resultados envejecería sus campos de Places sin borrarse → **ver AUD-012**
(job que expira/nulifica campos de Places no refrescados en 30 días). El modelo ya separa
`place_id` (permanente) de campos con `synced_at` (perecibles): la expiración es estructural.

### AUD-002 — Cláusula "No Use With Non-Google Maps" (ADR-007) 🟢 verificado (restrictivo)
**Veredicto (2026-07-07):** **Sigue vigente.** La política de Places es explícita: *"Places API
results displayed on a map must be shown on a Google Map"*. Plotear contenido de Places
(nombre, rating, ubicación) sobre Leaflet/OSM **viola los ToS**. → El mapa **no** puede ser
Leaflet+OSM con datos de Places.
**Decisión (2026-07-07): Plan A — Google Maps JS API.** Su cupo de mapas dinámicos cubre de
sobra a un solo usuario y permite plotear TODOS los datos (Places + manuales) sin violar ToS.
El Stimulus controller del mapa usará Google Maps JS en vez de Leaflet; el resto de la vista
(marcadores por estado, click → ficha) no cambia. El link "Cómo llegar" de la ficha ya es
válido (es un enlace, no un embed). Implementación en **AUD-010** (necesita la Maps JS API key).

### AUD-003 — Cupos por SKU vigentes de Places API (ADR-002) 🟢 verificado (diseño validado)
**Veredicto (2026-07-07):** **Confirmado.** Desde el 1-mar-2025 el crédito de US$200 se
reemplazó por cupos gratuitos **por SKU/mes**: **Essentials 10.000 · Pro 5.000 · Enterprise
1.000**. Nuestro Text Search pide rating/teléfono/`websiteUri` → cae en **Enterprise (1.000
gratis/mes)**, el cupo más chico, tal como anticipó ADR-002. Proyección: 48 combinaciones ×
~3 páginas ≈ **144 llamadas/mes = 14% del cupo** → dentro del margen ≥ 30% del NFR §9.
**Diseño ADR-002 validado.** No pedimos `reviews` (evita el tier Enterprise+Atmosphere, más caro).

### AUD-004 — Dominio y marca "Oteo" (SAD §16, v1.2.0) 🟢 resuelto
**Veredicto (2026-07-07):**
- **Marca INAPI: libre.** El autor verificó que "Oteo" no está registrado en INAPI → sin
  conflicto de marca para el nombre.
- **Dominio: no bloquea.** `oteo.cl`/`.com` están tomados pero el branding público no es
  prioridad de una herramienta interna; se resolverá con una variante cuando/si se necesite.
**Cierre:** el renombre Catastro → Oteo queda firme.

---

## Deuda técnica de implementación

### AUD-005 — `page_delay` real de paginación de Places no probado contra la API (ADR-002/011) 🔴
**Contexto:** `PlacesClient::PAGE_DELAY = 2s` es el valor histórico que Places exige para que
el `nextPageToken` quede activo. En tests se usa `page_delay: 0`. No se ha validado contra la
API real que 2s baste ni que el token se comporte como se asume.
**Plan de pago:** en el primer sync real de Fase 1 (Curicó × restaurantes), medir y ajustar.

### AUD-006 — Merge asistido de duplicados/ids renovados aún no implementado (ADR-013) 🔴
**Contexto:** el modelo soporta `place_id` nullable y ciclo de vida, pero la heurística de
merge (distancia < 50 m + teléfono/nombre normalizado) y el manejo de `NOT_FOUND` viven en
el SyncJob, que es trabajo de Fase 1. Hasta entonces no hay deduplicación.
**Plan de pago:** implementar en el SyncJob (Fase 1) con confirmación manual, nunca merge
automático destructivo.

### AUD-007 — CVE-2026-38969 en webrick 1.9.2 ignorado en bundler-audit 🟡
**Contexto:** `webrick` es dependencia transitiva **solo de test** (ferrum → cuprite, para
manejar Chrome headless en system specs). No corre en producción (server = Puma) ni se expone
a red. Sin versión parcheada disponible al día de hoy. Ignorado en `config/bundler-audit.yml`.
**Plan de pago:** `bundle update webrick` cuando salga la versión parcheada y quitar el ignore.

### AUD-008 — Verificación HTTP en vivo no implementada (ADR-003) 🔴
**Contexto:** `PresenceClassifier` es lógica pura (sin red). No resuelve acortadores
(bit.ly → destino real), no detecta dominios muertos/estacionados (`web_caida`), ni distingue
403 anti-bot de un sitio caído. `#shortener?` marca el caso pero no lo resuelve. Un dominio
propio muerto clasifica hoy como `web_propia` (lead perdido).
**Por qué se difiere:** meter N llamadas HTTP en cada sync lo vuelve lento y frágil; §13 ubica
"verificación HTTP de webs" en Fase 4.
**Plan de pago (Fase 4):** port `UrlResolver`/`SiteVerifier` inyectable — resolver acortadores
antes de clasificar y marcar `web_caida` solo con DNS/timeout/5xx (403/405 NO cuentan). Cada
caso raro se documenta en CASES.md antes de tocar las listas.
**Nota:** `PresenceClassifier#shortener?` ya detecta acortadores (tested) pero nadie lo cablea
todavía; hoy un `bit.ly` cae como `web_propia`. El SyncJob lo usará en Fase 4 para marcar el caso.

### AUD-009 — Subdivisión de consultas por corte de ~60 no implementada (ADR-011) 🔴
**Contexto:** `PlacesClient` corta en `MAX_PAGES = 3` (~60 resultados por prominencia). El
`SyncJob` aún no detecta el corte (60 resultados = señal) ni subdivide por sector/sinónimo.
El sesgo de prominencia (los mejores leads quedan fuera) no está corregido.
**Plan de pago (Fase 1.5 / donde el corte se detecte):** cuando una combinación devuelva 60,
subdividir la consulta por barrio o sinónimo del rubro, registrando cada sub-consulta en
`sync_runs`. El `SyncJob` ya acepta `query:` explícito para esto.

### AUD-010 — Mapa (tercera vista): ✅ implementado con Google Maps JS 🟢
**Cierre (2026-07-07):** las tres vistas del SAD §4.2 están completas. El mapa usa Google Maps
JS (Stimulus `map_controller.js`), marcadores coloreados por `digital_presence`, infowindow con
link a la ficha; JSON acotado al filtro activo (NFR §9). Renderizado verificado con datos reales
de Curicó. **Único pendiente operativo:** cargar la Maps JS API key (browser, referrer-restringida)
en `GOOGLE_MAPS_JS_API_KEY` o credentials `google.maps_js_api_key`; sin ella la vista muestra un
fallback claro. Historial de la decisión (por qué Google Maps y no Leaflet) abajo:

### AUD-010b — (histórico) por qué el mapa NO fue Leaflet 🔴
**Contexto:** Fase 2 entrega dos de las tres vistas (tabla y kanban). El **mapa Leaflet queda
fuera a propósito**: plotear datos de Places sobre un mapa no-Google puede violar los ToS
("No Use With Non-Google Maps"). Escribirlo hoy sería construir sobre un gate sin verificar.
**Decisión (2026-07-07):** AUD-002 resuelto → **Google Maps JS API** (plotea Places + manuales
sin violar ToS). Ya no está "bloqueado" sino "pendiente de implementar": necesita la Maps JS
API key (browser, restringida por HTTP referrer). El `show` ya expone lat/lng.
**Plan de pago:** Stimulus controller `map` que carga Google Maps JS, marcadores coloreados por
`digital_presence`, click → Turbo Frame con la ficha; JSON acotado al filtro activo (NFR §9).

### AUD-011 — Deploy con Kamal 🟢 PAGADO (2026-07-09, producción real)
**Cierre:** desplegado en una VM GCE `e2-small` (`southamerica-west1`, Santiago; crédito de
prueba, decidir permanencia ~día 50), IP estática `34.176.45.178`, dominio `oteo.duckdns.org`
(DuckDNS gratis), registry ghcr.io, SSH como usuario no-root con llave. Verificado:
- [x] `kamal setup` sin errores (~27 min primer build); `/up` → 200 con SSL Let's Encrypt válido,
      http→https sin loop (gracias a `assume_ssl`+`force_ssl` activados a tiempo).
- [x] `db:prepare` creó las 4 bases (primary + cache/queue/cable).
- [x] Recurring registrado (SyncAllJob 1 y 15, ExpirePlacesDataJob lunes) **y SyncAllJob corrió
      en producción** (disparo manual: 96/96 combinaciones success, 2237 negocios, 180 llamadas).
- [x] Backup **cifrado (age, clave pública en la VM, privada offline)** subido a
      `gs://oteo-backups-501721` vía metadata token (cero credenciales en disco), cron diario
      01:00 Chile, **restauración probada** (bucket → descifrado local → 2237 negocios) — ADR-010 ✓.
- [x] Endurecimiento SECURITY.md §3: firewall solo 22/80/443, Postgres en localhost, SSH solo
      llave, IAM del SA restringido a objetos del bucket.
**Deuda residual → AUD-013** (SSH público) y **AUD-014** (permanencia GCE).

### AUD-013 — SSH (puerto 22) abierto al mundo, sin IAP 🔴
**Contexto:** la VM usa la regla `default-allow-ssh` de GCP (22 público). Mitigado: solo auth
por llave (GCE deshabilita password). SECURITY.md §3 recomienda IAP TCP forwarding (saca el 22
de internet) — no se configuró en el primer deploy para no sumar fricción.
**Plan de pago:** configurar IAP o restringir la regla de firewall a IPs conocidas; evaluar
también fail2ban. Bajo riesgo real (llave ed25519), prioridad baja.

### AUD-014 — Permanencia del hosting: crédito GCE expira ~2026-09-02 🔴
**Contexto:** la VM corre con el crédito de prueba de GCP (90 días desde ~2026-06-04; quedaban
56 el 2026-07-08). Al expirar, GCE factura (~US$14/mes e2-small) — más caro que un VPS de
presupuesto (Hetzner ~€4.5/mes).
**Plan de pago (~día 50, ±2026-08-25):** decidir quedarse (habilitar facturación con budget
alert) o migrar: con Kamal es cambiar IP en `deploy.yml` + `kamal setup` + repuntar DuckDNS y
la restricción IP de la Places key (~30 min). El backup off-site vive en GCS: si se abandona
GCP, mover también el destino del backup.

### AUD-012 — Expiración de campos de Places a los 30 días (ADR-006 / AUD-001) 🟢 resuelto
**Cierre (Fase 3):** `ExpirePlacesDataJob` (recurrente semanal en `config/recurring.yml`)
nulifica los campos perecibles de Places de los registros con `synced_at` > ventana ToS,
marcando `places_expired`. Conserva `place_id`, identificación mínima (nombre/dirección) y
TODO el dato propio. El sync repuebla y resetea el flag al reencontrar el negocio.
**Nota de interpretación:** se conserva nombre/dirección como identificación mínima del lead
operativo (zona gris de los ToS para una herramienta interna); el resto del contenido de
Places se borra. La página de salud muestra "vencidos" (por refrescar) y "expirados".
