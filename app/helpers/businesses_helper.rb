module BusinessesHelper
  PRESENCE_LABELS = {
    "sin_presencia" => "Sin presencia",
    "solo_redes" => "Solo redes",
    "web_propia" => "Web propia",
    "web_caida" => "Web caída"
  }.freeze

  PRESENCE_BADGE = {
    "sin_presencia" => "bg-red-100 text-red-800",
    "solo_redes" => "bg-orange-100 text-orange-800",
    "web_propia" => "bg-gray-100 text-gray-600",
    "web_caida" => "bg-yellow-100 text-yellow-800"
  }.freeze

  POS_STATUS_LABELS = {
    "desconocido" => "Desconocido",
    "sin_sistema" => "Sin sistema",
    "caja_tradicional" => "Caja tradicional",
    "competidor" => "Competidor",
    "usa_el_nuestro" => "Usa el nuestro"
  }.freeze

  STAGE_LABELS = {
    "nuevo" => "Nuevo",
    "contactado" => "Contactado",
    "propuesta" => "Propuesta",
    "cerrado" => "Cerrado",
    "descartado" => "Descartado",
    "archivado" => "Archivado"
  }.freeze

  # Guion de venta por estado de presencia (ADR-003): tres estados = tres argumentos.
  SALES_SCRIPTS = {
    "sin_presencia" => "No aparece en internet: se le vende <strong>visibilidad</strong>. " \
                       "Tiene reputación en Maps pero nadie lo encuentra al buscar en Google.",
    "solo_redes" => "Depende de redes de terceros: se le vende <strong>profesionalización</strong> " \
                    "— una web propia que no dependa del algoritmo de Meta ni de una plataforma que cobra comisión.",
    "web_propia" => "Ya tiene web propia: <strong>no es lead de web</strong> (a lo más, rediseño). " \
                    "Evaluar solo por el ángulo POS.",
    "web_caida" => "Tiene dominio pero el sitio no responde: <strong>oportunidad de rescate/rediseño</strong>. " \
                   "Verificar antes de contactar."
  }.freeze

  # Color del marcador en el mapa por estado de presencia (ADR-007). Debe coincidir con
  # el mapa de colores del Stimulus controller (map_controller.js).
  PRESENCE_MARKER_COLOR = {
    "sin_presencia" => "#dc2626",
    "solo_redes" => "#ea580c",
    "web_propia" => "#9ca3af",
    "web_caida" => "#ca8a04"
  }.freeze

  def presence_color(state) = PRESENCE_MARKER_COLOR.fetch(state, "#6b7280")

  def presence_label(state) = PRESENCE_LABELS.fetch(state, "Sin clasificar")

  def presence_badge(state)
    classes = "inline-flex items-center px-2 py-0.5 rounded text-xs font-medium " \
              "#{PRESENCE_BADGE.fetch(state, 'bg-gray-100 text-gray-500')}"
    content_tag(:span, presence_label(state), class: classes)
  end

  def pos_status_label(status) = POS_STATUS_LABELS.fetch(status, status.to_s.humanize)
  def stage_label(stage) = STAGE_LABELS.fetch(stage, stage.to_s.humanize)

  def sales_script(state)
    SALES_SCRIPTS[state]&.html_safe
  end

  def lead_score_display(score)
    number_with_precision(score, precision: 1)
  end

  # website_uri viene de Places (dato externo): solo enlazar si es http/https,
  # nunca javascript:/data: (evita XSS vía href — Brakeman LinkToHref).
  def safe_external_url(uri)
    uri.to_s.match?(%r{\Ahttps?://}i) ? uri : nil
  end

  def lane_tab_class(active)
    base = "px-3 py-1.5 rounded-md text-sm font-medium "
    base + (active ? "bg-emerald-600 text-white" : "bg-white text-gray-600 border border-gray-200 hover:bg-gray-50")
  end
end
