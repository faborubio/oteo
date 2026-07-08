# CASES.md — Memoria del clasificador de presencia digital

> Casos reales de clasificación (ADR-003): URIs raros de producción y qué se decidió.
> **Regla (SAD §14):** antes de tocar las listas de `config/oteo.yml`, el caso se documenta
> aquí con su URI real. Alimenta la lista configurable y el test suite.

Formato: `| URI / señal | Clasificación decidida | Razón | Fecha |`

## Reglas base (de ADR-003, ya en `config/oteo.yml`)
| Señal | Clasificación | Nota |
|---|---|---|
| `websiteUri` vacío | `sin_presencia` | señal primaria |
| dominio en `social_domains` (facebook, instagram, linktr.ee, wa.me, tiktok…) | `solo_redes` | redes ≠ web propia |
| dominio en `aggregator_domains` (PedidosYa, Rappi, UberEats, Justo…) | `solo_redes` | plataforma de terceros; excelente lead |
| subdominio en `site_builder_domains` (ueniweb.com, wixsite.com, business.site…) | `solo_redes` | página de constructor plantilla, no web propia |
| dominio en `url_shorteners` (bit.ly, cutt.ly…) | resolver redirect primero | esconde el destino |
| cualquier otro dominio | `web_propia` | candidato a descarte o rediseño |
| DNS falla / timeout / 5xx | `web_caida` | 403/405 NO cuentan como caída (anti-bot) |

## Casos de producción

### Sync real Curicó × restaurantes — 2026-07-07 (n=20)
18/20 correctos. Dos hallazgos:

| URI / señal | Antes | Decidido | Razón |
|---|---|---|---|
| `trattoria-de-vali.ueniweb.com/?utm_campaign=gmb` | `web_propia` | **`solo_redes`** | **UENI** es un constructor de sitios plantilla (subdominio `*.ueniweb.com`), autogenerado (`utm_campaign=gmb`). No es web propia → es lead. Se agrega `site_builder_domains` a `config/oteo.yml` con los constructores más comunes. |
| `cartas.horecaqr.com/c/trattorialapasta` | `web_propia` | **`solo_redes`** | **HorecaQR** es una plataforma de **menús QR** multi-tenant (una ficha por restaurante). No es web propia. Se agrega `horecaqr.com` a `site_builder_domains`. |
| `malldecurico.cl/tiendas/mamut/` | `web_propia` | **limitación conocida** | Es una ficha en el **directorio de un mall**, no el sitio del negocio. No generalizable por lista (cada mall es un dominio distinto). Detectarlo pide heurística de "página de directorio" → ligado a **AUD-008** (verificación HTTP, Fase 4). Por ahora queda como falso `web_propia`. |

### Populate del Maule — 2026-07-08 (n=2257, 12 comunas)
70% `sin_presencia` (1595), 16% `web_propia` (352), 14% `solo_redes` (310). Auditados los
hosts de `web_propia`: las cadenas (cruzverde.cl, drsimi.cl, salcobrand.cl, unimarc.cl, lider.cl,
copec…) quedan BIEN como web_propia — no son leads y score 0 los entierra correctamente. Cuatro
plataformas de terceros se colaban como falso `web_propia` (leads enterrados):

| URI / señal | Antes | Decidido | Razón |
|---|---|---|---|
| `menu.fu.do/...` | `web_propia` | **`solo_redes`** | **Fu.do**: plataforma de menús/gestión para restaurantes. → `fu.do` a `site_builder_domains`. |
| `*.pedix.app` | `web_propia` | **`solo_redes`** | **Pedix**: plataforma de pedidos online. → `pedix.app` a `site_builder_domains`. |
| `wa.link/...` | `web_propia` | **`solo_redes`** | Landing de WhatsApp (tipo linktr.ee). → `wa.link` a `social_domains`. |
| `fresha.com/...` | `web_propia` | **`solo_redes`** | **Fresha**: plataforma de reservas (peluquerías/spa). → `fresha.com` a `aggregator_domains`. |

**Cadenas nacionales** (cruzverde.cl, drsimi.cl, unimarc.cl…): correctamente `web_propia`; NO
son leads (no se les vende web a una sucursal). Score 0 los saca del ranking — comportamiento correcto.

### Segunda auditoría de `web_propia` — 2026-07-08 (populate del Maule, n=2257)

Auditados TODOS los hosts que no terminan en `.cl` dentro de `web_propia` (la primera pasada
del 2026-07-08 solo cubrió 4 plataformas). Aparece una capa completa de subdominios de
plataformas de terceros: **33 leads enterrados** con score 0. Movidos a `solo_redes`.

| URI / señal | Antes | Decidido | Razón |
|---|---|---|---|
| `*.site.agendapro.com`, `*.agendapro.com`, `link.agendapro.com` | `web_propia` | **`solo_redes`** | **AgendaPro**: SaaS de reservas para peluquerías/barberías/spa (9 negocios: Barbería Status, Basics, Giordano, Salon Essentials…). → `agendapro.com` a `site_builder_domains`. |
| `toteat.app/r/cl/...` | `web_propia` | **`solo_redes`** | **Toteat**: gestión/menú de restaurantes (Chile). → `site_builder_domains`. |
| `*.ola.click` | `web_propia` | **`solo_redes`** | **Ola.click**: pedidos online (Chile). → `site_builder_domains`. |
| `oddmenu.com/...` | `web_propia` | **`solo_redes`** | **OddMenu**: menú digital multi-tenant. → `site_builder_domains`. |
| `restomovil.com/mkt/carta/...` | `web_propia` | **`solo_redes`** | **Restomóvil**: landing/carta plantilla de restaurantes. → `site_builder_domains`. |
| `*.kyte.site` | `web_propia` | **`solo_redes`** | **Kyte**: catálogo/tienda plantilla. → `site_builder_domains`. |
| `*.skedu.com`, `book.heygoldie.com` | `web_propia` | **`solo_redes`** | Plataformas de reservas. → `site_builder_domains`. |
| `pedixwpp.com/...` | `web_propia` | **`solo_redes`** | Variante WhatsApp de Pedix. → `site_builder_domains`. |
| `*.webnode.es`, `*.wordpress.com`, `*.github.io` | `web_propia` | **`solo_redes`** | Subdominios gratuitos de constructor/host (Webnode, WordPress.com, GitHub Pages). El dominio propio `.cl` sobre el mismo constructor NO matchea. → `site_builder_domains`. |
| `drive.google.com/file/...` | `web_propia` | **`solo_redes`** | Carta en PDF alojada en Drive, no sitio propio. → `site_builder_domains`. |
| `bio.site`, `bio.link`, `linkinsta.com`, `msha.ke`, `w.app` | `web_propia` | **`solo_redes`** | Link-in-bio / landing de WhatsApp (tipo linktr.ee). → `social_domains`. |
| `g.page/r/.../review` | `web_propia` | **`solo_redes`** | Link corto al Perfil de Empresa de Google (reseñas), no web propia. → `social_domains`. |
| `mercantil.com/empresa/...` | `web_propia` | **`solo_redes`** | Directorio de empresas B2B (3 negocios). → `aggregator_domains`. |
| `booking.com/...`, `tripadvisor.com.ar/pe/...` | `web_propia` | **`solo_redes`** | Agregadores de viaje/reservas. → `aggregator_domains`. |

**Own domains que quedan BIEN** en `web_propia` (NO se tocan): restaurantgermania.com,
lagarhotel.com, casadeamalia.com, cassiscafe.com, peluqueriaguapas.com, etc. — dominio propio
de marca (aunque `.com`), no plataforma. Y las cadenas nacionales `.cl` ya validadas.

**Watchlist de constructores** (agregar cuando aparezcan con URI real): `myshopify.com`,
`square.site`, `webflow.io`, `netlify.app`, `vercel.app`, `blogspot.com`.
Ojo: solo el **subdominio por defecto** del constructor es señal; si el negocio usa el mismo
constructor con dominio propio (`.cl`), eso SÍ es web propia.
