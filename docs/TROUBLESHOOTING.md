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

## Vistas / assets

### `LoadError: cannot load such file -- pagy/extras/overflow` al arrancar
**Causa:** Pagy en este repo es la **v43** (rewrite moderno), no la 9.x de la mayoría de tutoriales.
En v43 no existen los `extras/` y `Pagy::DEFAULT` está **congelado** (no se puede mutar en un initializer).
**Fix:** no usar initializer. API v43: `include Pagy::Method` en ApplicationController;
`@pagy, @x = pagy(scope, limit: 30)`; en la vista `<%== @pagy.series_nav %>` (no `pagy_nav`).
No incluir `Pagy::Frontend` en helpers. FleetPilot usa la misma versión: mirar ahí si hay dudas.

### La app carga pero SIN estilos (HTML pelado, Tailwind no aplica)
**Causa:** el setup de Tailwind quedó incompleto porque el `bundle` del `rails new` original
falló a mitad → no existía `app/assets/builds/tailwind.css`, el `Procfile.dev` estaba vacío y
el layout linkeaba `:app` (asset inexistente) en vez del build de Tailwind.
**Fix (ya aplicado):** `bin/rails tailwindcss:install` (crea input `app/assets/tailwind/application.css`,
`Procfile.dev`, `bin/dev`, y compila el build). El layout linkea `stylesheet_link_tag "tailwind"`.
**Operar:** usar **`bin/dev`** (no `bin/rails server`): corre el watcher que recompila el CSS al
tocar vistas. El build (`app/assets/builds/tailwind.css`) está gitignoreado → en CI se genera con
`bin/rails tailwindcss:build` antes de los specs (el layout lo linkea y propshaft falla si falta).

## Base de datos

### `ActiveRecord::PendingMigrationError` al correr specs
**Causa:** hay migraciones sin aplicar en la BD de test.
**Fix:** `bin/rails db:test:prepare`.

### `PG::ConnectionBad` / no conecta a Postgres
**Causa:** el servidor Postgres no está corriendo o el rol no existe.
**Fix:** `pg_isready` para confirmar; el rol del sistema debe existir en `pg_roles`.

---

## Google Places (Fase 1+)

### `NameError: uninitialized constant Net::HTTP` en el primer sync real
**Qué pasó:** `PlacesClient` usa `Net::HTTP` pero no hacía `require "net/http"`. Toda la suite
pasaba en verde porque **WebMock carga `net/http` por su cuenta** en el entorno de test; en un
sync real (sin WebMock) la constante no estaba cargada.
**Por qué:** el stub de tests enmascaró una dependencia faltante — "pasa en tests, falla en producción".
**Qué cambió:** `require "net/http"` (y `uri`, `json`) al inicio de `app/services/places_client.rb`.
Verificado con una llamada real de key inválida: devuelve `Result` con error HTTP, no `NameError`.


### `PlacesClient::Result#error` con `HTTP 429` / `RESOURCE_EXHAUSTED`
**Causa:** cuota del SKU agotada (ADR-002).
**Fix:** el SyncJob debe abortar y alertar (driver #2: jamás pasar a facturación). Revisar
`SyncRun.api_calls_this_month` contra el cupo. Ver AUD-003.

### `HTTP 403` de una web al verificar presencia (Fase 4)
**Causa:** anti-bot; el sitio está vivo pero bloquea. **No** es `web_caida` (ADR-003).
**Fix:** solo DNS/timeout/5xx marcan `web_caida`; 403/405 se reintenta o se ignora.

---

## Deploy real (AUD-011, 2026-07-09)

### `Permission denied (API_KEY_IP_ADDRESS_BLOCKED)` con la IP correcta autorizada
**Qué pasó:** el primer sync real falló con 403 pese a haber autorizado la IPv4 pública en la
restricción de la Places key.
**Por qué:** la conexión es dual-stack y salió por **IPv6** con extensiones de privacidad (el
sufijo rota; el prefijo /64 es estable). Google vio la IPv6, no la IPv4 autorizada.
**Fix:** autorizar el **prefijo `/64`** de la IPv6 (no la dirección exacta) además de la IPv4.
En producción no aplica: la VM tiene IP estática y es la única autorizada.

### Upload del backup a GCS → `HTTP 403` con el scope correcto
**Qué pasó:** la VM tenía scope `devstorage.read_write` pero el upload devolvía 403.
**Por qué:** scope ≠ IAM: el scope limita lo que la VM *puede pedir*; el rol IAM define lo que
la service account *tiene permitido*. En proyectos GCP nuevos, el SA default de Compute ya no
recibe roles automáticos.
**Fix:** rol **Storage Object Admin** otorgado al SA, **acotado al bucket** (mínimo privilegio,
SECURITY.md §3). Nota: cambiar el *scope* requiere detener/arrancar la VM; el *rol* no.

### Restauración del backup con `ERROR: role "oteo" does not exist` (cosmético)
**Qué pasó:** al restaurar el dump en la máquina local, decenas de errores de rol; los datos
entraron completos igual.
**Por qué:** el dump incluía `OWNER TO oteo` y el rol solo existe en producción.
**Fix:** `pg_dump --no-owner --no-acl` en `script/pg_backup.sh` → restauraciones limpias en
cualquier rol.

### `bin/dev` muere solo a los segundos de arrancar (dev)
**Qué pasó:** foreman envía SIGTERM a todo si *cualquier* proceso del Procfile termina; el
watcher de Tailwind (`css`) salió con código 0 y tumbó al server web.
**Fix operativo:** para revisar la UI sin tocar CSS basta `bin/rails server`. Si pasa de nuevo
con `bin/dev`, revisar por qué el watcher de Tailwind sale (versión del gem / inotify en WSL).

<!--
Plantilla de postmortem (falla con impacto real):
### [FECHA] Título del incidente
**Qué pasó:** ...
**Por qué:** ...
**Qué cambió para que no se repita:** ... (link al commit / AUD / CASES)
-->
