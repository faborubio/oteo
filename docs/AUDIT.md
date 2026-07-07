# AUDIT.md — Deuda técnica y atajos conscientes

> Formato `AUD-NNN`. Todo trade-off "aceptado" en un ADR que implique trabajo futuro tiene
> su entrada aquí (SAD §14, regla 2). Un trade-off sin AUD es deuda invisible.
> Estados: 🔴 abierto · 🟡 en curso · 🟢 pagado/verificado.

---

## Gates legales de Fase 0 (bloquean decisiones de arquitectura — verificación humana)

### AUD-001 — ToS de retención de datos de Places (ADR-006) 🔴
**Contexto:** el modelo asume que `place_id` se guarda indefinidamente y el resto de los
datos de Places se refresca dentro de una ventana (`places_retention_days: 30` en
`config/oteo.yml`). Ese valor es un supuesto.
**Acción:** verificar la versión vigente de los Terms of Service de Places sobre caché y
retención, y ajustar `places_retention_days`.
**Impacto si se ignora:** riesgo de violar el contrato que hace viable la fuente (driver #3).
**Veredicto:** _pendiente_. **Fecha:** —

### AUD-002 — Cláusula "No Use With Non-Google Maps" (ADR-007) 🔴
**Contexto:** el plan es plotear resultados de Places sobre Leaflet + OpenStreetMap. Los ToS
de Google Maps Platform han prohibido históricamente mostrar datos de sus servicios sobre un
mapa que no sea de Google.
**Acción:** verificar la cláusula vigente antes de implementar el mapa (Fase 2).
**Plan B si sigue activa:** (a) Google Maps JS API (cupo gratuito cubre a un solo usuario;
el Stimulus controller cambia de librería sin tocar el resto), o (b) Leaflet solo con datos
propios/manuales (ADR-012).
**Veredicto:** _pendiente_. **Fecha:** —

### AUD-003 — Cupos por SKU vigentes de Places API (ADR-002) 🔴
**Contexto:** desde 2025 Google reemplazó el crédito mensual de US$200 por cupos mensuales
por SKU (≈10.000 Essentials / 5.000 Pro / 1.000 Enterprise). El field mask actual
(`websiteUri`, teléfono) eleva la llamada a Enterprise, el cupo más chico. Proyección con
ADR-002: ~144 llamadas/mes — holgado, pero sobre valores que hay que confirmar.
**Acción:** confirmar los cupos por SKU vigentes y validar que 48 combinaciones × ~3 páginas
caben en el free tier con margen ≥ 30% (NFR §9).
**Veredicto:** _pendiente_. **Fecha:** —

### AUD-004 — Dominio y marca "Oteo" (SAD §16, v1.2.0) 🔴
**Contexto:** el renombre Catastro → Oteo se hizo tras verificar por búsqueda web que no hay
conflicto comercial evidente en Chile, pero falta confirmación formal.
**Acción:** confirmar disponibilidad de dominio en **nic.cl** y de marca en **INAPI**
(clases 9 y 42).
**Veredicto:** _pendiente_. **Fecha:** —

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
