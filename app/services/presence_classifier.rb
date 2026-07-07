# Clasifica la presencia digital de un negocio en tres estados (ADR-003) a partir de
# su website_uri. Redes sociales y agregadores de terceros NO son web propia.
#
# Es lógica pura (sin red): la verificación HTTP en vivo — resolver acortadores y
# detectar sitios caídos (web_caida) — es Fase 4 (ver AUD-008). Aquí un acortador no
# resuelto se marca como caso a revisar, no se adivina su destino.
#
# Las listas de dominios viven en config/oteo.yml (ADR-003), no en código.
class PresenceClassifier
  SIN_PRESENCIA = "sin_presencia".freeze
  SOLO_REDES = "solo_redes".freeze
  WEB_PROPIA = "web_propia".freeze

  def self.call(website_uri)
    new(website_uri).call
  end

  def initialize(website_uri)
    @website_uri = website_uri.to_s.strip
  end

  def call
    return SIN_PRESENCIA if website_uri.blank?

    host = normalized_host
    return WEB_PROPIA if host.blank? # URI rara pero presente: no la enterramos como sin_presencia

    return SOLO_REDES if match?(host, social_domains)
    return SOLO_REDES if match?(host, aggregator_domains)
    return SOLO_REDES if match?(host, site_builder_domains)

    WEB_PROPIA
  end

  # ¿El host es un acortador cuyo destino no conocemos sin resolver el redirect?
  # El SyncJob puede usar esto para marcar el caso (CASES.md) en vez de clasificar a ciegas.
  def shortener?
    host = normalized_host
    host.present? && match?(host, url_shorteners)
  end

  private

  attr_reader :website_uri

  def normalized_host
    uri = website_uri.match?(%r{\Ahttps?://}i) ? website_uri : "https://#{website_uri}"
    host = URI.parse(uri).host
    host&.downcase&.delete_prefix("www.")
  rescue URI::InvalidURIError
    nil
  end

  # Coincide con el dominio exacto o cualquier subdominio (m.facebook.com, chat.whatsapp.com).
  def match?(host, domains)
    domains.any? { |d| host == d || host.end_with?(".#{d}") }
  end

  def social_domains = config.social_domains
  def aggregator_domains = config.aggregator_domains
  def site_builder_domains = config.site_builder_domains
  def url_shorteners = config.url_shorteners
  def config = Rails.configuration.oteo
end
