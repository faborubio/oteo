# Adapter tras una interfaz para Google Places API (New) — ADR-002.
#
# Regla de oro de cuota: TODOS los campos se piden en el field mask del propio
# Text Search (searchText). Nunca Place Details por lugar. El SKU se cobra por
# búsqueda, no por resultado: 48 combinaciones × ~3 páginas ≈ 144 llamadas/mes.
#
# El dominio consume `Snapshot` normalizado, no el JSON de Google: si Places
# cambia de versión o se agrega otra fuente, solo cambia este archivo (ADR-002/003).
#
# Docs: https://developers.google.com/maps/documentation/places/web-service/text-search
class PlacesClient
  ENDPOINT = "https://places.googleapis.com/v1/places:searchText".freeze

  # Field mask: define qué campos vuelven Y el SKU facturado. Pedir websiteUri/teléfono
  # eleva la llamada a Enterprise (cupo más chico) — aceptado en ADR-002.
  FIELD_MASK = %w[
    places.id
    places.displayName
    places.formattedAddress
    places.location
    places.rating
    places.userRatingCount
    places.websiteUri
    places.nationalPhoneNumber
    places.types
    places.businessStatus
    nextPageToken
  ].join(",").freeze

  MAX_PAGES = 3            # Text Search corta en ~60 resultados / 3 páginas (ADR-011)
  PAGE_DELAY = 2          # Places exige esperar a que el nextPageToken quede activo
  OPEN_TIMEOUT = 5
  READ_TIMEOUT = 15

  # Registro normalizado que consume el dominio. No es el JSON de Google.
  Snapshot = Data.define(
    :place_id, :name, :address, :lat, :lng, :phone,
    :rating, :user_rating_count, :website_uri, :types, :business_status
  )

  # Resultado de una búsqueda: los snapshots, el costo en llamadas (para sync_runs,
  # ADR-002) y el error si la búsqueda falló.
  Result = Data.define(:snapshots, :api_calls, :error) do
    def success? = error.nil?
  end

  class << self
    def search(query, **opts)
      new(**opts).search(query)
    end
  end

  def initialize(api_key: self.class.default_api_key, max_pages: MAX_PAGES, page_delay: PAGE_DELAY)
    @api_key = api_key
    @max_pages = max_pages
    @page_delay = page_delay
  end

  def self.default_api_key
    ENV["GOOGLE_PLACES_API_KEY"].presence ||
      Rails.application.credentials.dig(:google, :places_api_key)
  end

  # Devuelve un Result con los Snapshot paginados (hasta max_pages). Nunca lanza:
  # los errores viajan en Result#error para que el SyncJob los registre y reintente.
  def search(query)
    snapshots = []
    calls = 0
    return Result.new(snapshots:, api_calls: 0, error: "API key ausente") if api_key.blank?

    page_token = nil
    max_pages.times do |page|
      sleep(page_delay) if page.positive? && page_delay.positive?

      response = post(text_query: query, page_token: page_token)
      calls += 1
      raise "HTTP #{response.code}: #{response.body}" unless response.is_a?(Net::HTTPSuccess)

      data = JSON.parse(response.body)
      Array(data["places"]).each { |place| snapshots << map(place) }

      page_token = data["nextPageToken"]
      break if page_token.blank?
    end

    Result.new(snapshots:, api_calls: calls, error: nil)
  rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, JSON::ParserError, RuntimeError => e
    Rails.logger.warn("PlacesClient search failed for #{query.inspect}: #{e.class} #{e.message}")
    Result.new(snapshots:, api_calls: calls, error: "#{e.class}: #{e.message}")
  end

  private

  attr_reader :api_key, :max_pages, :page_delay

  def post(text_query:, page_token:)
    uri = URI(ENDPOINT)
    body = { textQuery: text_query, languageCode: "es", regionCode: "CL" }
    body[:pageToken] = page_token if page_token.present?

    Net::HTTP.start(uri.host, uri.port, use_ssl: true,
                    open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT) do |http|
      request = Net::HTTP::Post.new(uri)
      request["Content-Type"] = "application/json"
      request["X-Goog-Api-Key"] = api_key
      request["X-Goog-FieldMask"] = FIELD_MASK
      request.body = body.to_json
      http.request(request)
    end
  end

  def map(place)
    Snapshot.new(
      place_id: place["id"],
      name: place.dig("displayName", "text"),
      address: place["formattedAddress"],
      lat: place.dig("location", "latitude"),
      lng: place.dig("location", "longitude"),
      phone: place["nationalPhoneNumber"],
      rating: place["rating"],
      user_rating_count: place["userRatingCount"].to_i,
      website_uri: place["websiteUri"],
      types: Array(place["types"]),
      business_status: place["businessStatus"]
    )
  end
end
