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
| dominio en `url_shorteners` (bit.ly, cutt.ly…) | resolver redirect primero | esconde el destino |
| cualquier otro dominio | `web_propia` | candidato a descarte o rediseño |
| DNS falla / timeout / 5xx | `web_caida` | 403/405 NO cuentan como caída (anti-bot) |

## Casos de producción
_Aún sin casos. El primer sync real (Curicó × restaurantes, Fase 1) los empezará a poblar._

<!--
Ejemplo de entrada futura:
| https://menu.canva.site/xyz | solo_redes | menú publicado en Canva, no es web propia; agregar canva.site a social_domains | 2026-07-XX |
-->
