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

  # Plantillas de mensaje por estado de presencia (SAD §13 Fase 3). La herramienta prepara
  # el argumento; el contacto es manual y personalizado (fuera de alcance §1.3, nada de envío
  # automático). %{name} se interpola con el nombre del negocio.
  CONTACT_TEMPLATES = {
    "sin_presencia" => "Hola! Vi %{name} en Google Maps, tienen muy buenas reseñas. Me llamó la " \
                       "atención que no aparecen con página web al buscarlos en Google. Ayudo a negocios " \
                       "como el suyo a tener una web simple para que los encuentren más fácil. ¿Le interesaría verla?",
    "solo_redes" => "Hola! Encontré a %{name} en redes y vi que les va muy bien. Una web propia haría que " \
                    "no dependan solo del algoritmo de Instagram/Facebook y aparezcan primeros en Google. " \
                    "¿Le muestro un ejemplo sin compromiso?",
    "web_propia" => "Hola! Vi la web de %{name}. Además de rediseños, ofrezco un sistema de punto de venta " \
                    "(POS) simple y económico. ¿Le interesaría que conversemos?",
    "web_caida" => "Hola! Quise ver la web de %{name} pero no está cargando. Puedo ayudarles a recuperarla " \
                   "o hacer una nueva, moderna y rápida. ¿Conversamos?"
  }.freeze

  def contact_template(business)
    template = CONTACT_TEMPLATES[business.digital_presence] || CONTACT_TEMPLATES["sin_presencia"]
    format(template, name: business.name)
  end

  # Link a WhatsApp con el mensaje pre-cargado (wa.me exige solo dígitos con código país).
  # Places a veces devuelve el teléfono en formato nacional (sin +56): se antepone el código
  # país de Chile cuando falta (ningún prefijo nacional chileno empieza con 56).
  def whatsapp_link(business)
    digits = business.phone.to_s.gsub(/\D/, "")
    return nil if digits.length < 8

    digits = "56#{digits}" unless digits.start_with?("56")
    "https://wa.me/#{digits}?text=#{CGI.escape(contact_template(business))}"
  end

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
