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
**Decisión resultante:** para la vista mapa, elegir una de dos (ambas ya previstas en ADR-007):
  (a) **Google Maps JS API** — su cupo de mapas dinámicos (Essentials) cubre de sobra a un
      usuario; el Stimulus controller cambia de librería sin tocar el resto; **o**
  (b) **Leaflet solo con datos manuales** (ADR-012), que son dato propio, no contenido de Places.
El link "Cómo llegar" a Google Maps de la ficha **sí es válido** (es un enlace, no un embed de
datos sobre otro mapa). El mapa sigue bloqueado en **AUD-010** hasta elegir plan.

### AUD-003 — Cupos por SKU vigentes de Places API (ADR-002) 🟢 verificado (diseño validado)
**Veredicto (2026-07-07):** **Confirmado.** Desde el 1-mar-2025 el crédito de US$200 se
reemplazó por cupos gratuitos **por SKU/mes**: **Essentials 10.000 · Pro 5.000 · Enterprise
1.000**. Nuestro Text Search pide rating/teléfono/`websiteUri` → cae en **Enterprise (1.000
gratis/mes)**, el cupo más chico, tal como anticipó ADR-002. Proyección: 48 combinaciones ×
~3 páginas ≈ **144 llamadas/mes = 14% del cupo** → dentro del margen ≥ 30% del NFR §9.
**Diseño ADR-002 validado.** No pedimos `reviews` (evita el tier Enterprise+Atmosphere, más caro).

### AUD-004 — Dominio y marca "Oteo" (SAD §16, v1.2.0) 🟡 parcial
**Veredicto (2026-07-07):**
- **Dominio `oteo.cl`: NO disponible.** Registrado por *Alex Verdugo* desde 2019-08-24, expira
  2030 (WHOIS de NIC Chile). → Buscar alternativa (`oteo.app`, `getoteo.cl`, `oteoapp.cl`,
  `oteo.dev`) o contactar al titular. **No bloquea el desarrollo**, sí el branding público.
- **Marca INAPI: pendiente.** El Buscador de Marcas de INAPI es una herramienta interactiva
  que no pude consultar automáticamente. **Acción humana:** buscar "Oteo" en
  https://www.inapi.cl → Buscador de marcas, clases 9 (software) y 42 (SaaS).

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

### AUD-010 — Mapa (tercera vista) NO implementado: bloqueado por gate legal (ADR-007 / AUD-002) 🔴
**Contexto:** Fase 2 entrega dos de las tres vistas (tabla y kanban). El **mapa Leaflet queda
fuera a propósito**: plotear datos de Places sobre un mapa no-Google puede violar los ToS
("No Use With Non-Google Maps"). Escribirlo hoy sería construir sobre un gate sin verificar.
**Depende de:** AUD-002. Cuando se resuelva:
- Si la cláusula sigue activa → Plan B: Google Maps JS API, o Leaflet solo con datos manuales.
- El `BusinessesController#show` ya expone lat/lng y hay un link "Cómo llegar" a Google Maps
  (un link normal, no un embed: eso sí es ToS-safe).
**Plan de pago:** implementar la vista mapa en un Stimulus controller aislado una vez despejado
el gate, sin tocar el resto (la coordenada ya está en el modelo).

### AUD-011 — Deploy con Kamal no ejecutado 🔴
**Contexto:** Fase 2 según el SAD termina con "deploy Kamal y salir a terreno". El deploy real
necesita el VPS, secrets (`RAILS_MASTER_KEY`, registry) y los gates legales despejados. La
config base de Kamal existe (`config/deploy.yml`, `.kamal/secrets`) pero no se ha desplegado.
**Plan de pago:** configurar `config/deploy.yml` (host, registry, dominio), cargar secrets y
correr `kamal setup`; probar el `pg_dump` de backup (ADR-010) una vez.

### AUD-012 — Expiración de campos de Places a los 30 días (ADR-006 / AUD-001) 🔴
**Contexto:** los ToS obligan a **borrar** el contenido de Places (nombre, rating, teléfono,
lat/lng…) cacheado más de 30 días; solo `place_id` es permanente. El sync quincenal refresca
los negocios que reaparecen en resultados, pero uno que deja de aparecer (cerró, cambió de
rubro, cayó del corte) envejecería sus campos sin borrarse → incumplimiento silencioso.
**Plan de pago (Fase 3):** job recurrente que nulifica los campos de Places (no el `place_id`
ni el dato propio) de registros con `synced_at` > 30 días; la UI ya tolera "dato vencido".
Va de la mano con la página de salud y el sync programado de Fase 3.
