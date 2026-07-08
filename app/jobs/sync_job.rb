# Sincroniza una combinación comuna × rubro desde Google Places (Fase 1).
#
# Idempotente por diseño (SAD §8): upsert por place_id, agrega el rubro sin reemplazar
# (ADR-013) y NUNCA toca los campos manuales (pos_status, pos_vendor, pipeline_stage,
# notas). Re-ejecutarlo no duplica filas ni pisa dato de terreno.
#
# Cuota (driver #2, ADR-002): cada corrida audita api_calls en su SyncRun. Si Places
# devuelve agotamiento de cuota, aborta y alerta — jamás reintenta hasta facturar.
class SyncJob < ApplicationJob
  queue_as :default

  # Error transitorio de Places (timeout, 5xx): se reintenta con backoff. La cuota NO
  # (se aborta, ver #handle_failure); los bugs de código tampoco (fallan rápido).
  class TransientError < StandardError; end

  retry_on TransientError, wait: :polynomially_longer, attempts: 3

  def perform(comuna_id, rubro_id, query: nil)
    comuna = Comuna.find(comuna_id)
    rubro = Rubro.find(rubro_id)
    text_query = query.presence || default_query(rubro, comuna)

    run = SyncRun.create!(comuna:, rubro:, query: text_query, status: "running", started_at: Time.current)

    result = PlacesClient.search(text_query)
    run.update!(api_calls: result.api_calls)

    return handle_failure(run, result.error) unless result.success?

    counters = { found: 0, new: 0, updated: 0, errors: 0 }
    result.snapshots.each { |snapshot| ingest(snapshot, comuna:, rubro:, counters:) }

    run.update!(
      status: "success", finished_at: Time.current,
      found_count: counters[:found], new_count: counters[:new],
      updated_count: counters[:updated], error_count: counters[:errors]
    )
    run
  rescue StandardError => e
    # Nunca dejar el run colgado en "running": un fallo inesperado debe ser visible en
    # el tablero de salud (§8). handle_failure ya marca failed en sus caminos; esto cubre
    # el resto y re-lanza para que retry_on/ActiveJob decidan.
    run&.running? && run.update!(status: "failed", finished_at: Time.current, notes: e.message)
    raise
  end

  private

  def default_query(rubro, comuna)
    "#{rubro.text_search_query} en #{comuna.name}, Chile"
  end

  # Aborta sin reintentar si es cuota (driver #2); reintenta si es transitorio.
  def handle_failure(run, error)
    if quota_error?(error)
      run.update!(status: "failed", finished_at: Time.current, notes: "CUOTA AGOTADA: #{error}")
      Rails.logger.error("SyncJob abortado por cuota (ADR-002 / driver #2): #{error}")
      return run
    end

    run.update!(status: "failed", finished_at: Time.current, notes: error)
    raise TransientError, error.to_s
  end

  def quota_error?(error)
    error.to_s.match?(/429|RESOURCE_EXHAUSTED/i)
  end

  def ingest(snapshot, comuna:, rubro:, counters:)
    counters[:found] += 1

    # Guard: un place_id en blanco (dato malformado de Places) matchearía por
    # find_or_initialize a un negocio MANUAL (place_id nil) y lo pisaría (ADR-012).
    # Se omite y se cuenta como error, nunca se toca dato de terreno.
    if snapshot.place_id.blank?
      counters[:errors] += 1
      Rails.logger.warn("SyncJob: snapshot sin place_id, se omite: #{snapshot.name.inspect}")
      return
    end

    business = upsert(snapshot, comuna:)
    add_rubro(business, rubro)
    counters[business.previously_new_record? ? :new : :updated] += 1
  rescue StandardError => e
    # Resiliencia de batch: un registro malo (validación, carrera RecordNotUnique entre
    # workers, etc.) no debe tumbar la corrida entera. Se cuenta y se sigue.
    counters[:errors] += 1
    Rails.logger.warn("SyncJob: fallo al procesar #{snapshot.place_id}: #{e.class} #{e.message}")
  end

  def upsert(snapshot, comuna:)
    business = Business.find_or_initialize_by(place_id: snapshot.place_id)
    business.source = "places"
    # La comuna se fija en el primer hallazgo, desde la consulta de origen (ADR-013):
    # no se re-parsea ni se pisa en syncs posteriores.
    business.comuna = comuna if business.new_record?

    apply_places_fields(business, snapshot)
    BusinessClassifier.classify(business)
    newly_archived = detect_archive(business)

    business.save!
    log_archive_event(business) if newly_archived
    business
  end

  # Copia solo los campos de Places (perecibles, ADR-006). No toca campos manuales.
  def apply_places_fields(business, snapshot)
    business.name = snapshot.name
    business.address = snapshot.address
    business.lat = snapshot.lat
    business.lng = snapshot.lng
    business.phone = snapshot.phone
    business.rating = snapshot.rating
    business.user_rating_count = snapshot.user_rating_count
    business.website_uri = snapshot.website_uri
    business.types = snapshot.types
    business.business_status = snapshot.business_status
    business.synced_at = Time.current
    business.places_expired = false # refrescado → ya no está vencido (AUD-012)
  end

  # Cierre permanente → archivado automático (ADR-013). Devuelve true solo en la
  # transición (una sola vez): re-sincronizar un cerrado ya archivado no re-dispara nada.
  def detect_archive(business)
    return false unless business.status_closed_permanently?
    return false if business.stage_archivado?

    business.pipeline_stage = "archivado"
    true
  end

  # El historial es evidencia de mercado: no se borra, se registra el cierre (ADR-013).
  def log_archive_event(business)
    business.contact_events.create!(
      event_type: "sistema",
      body: "Archivado automáticamente: Google reporta CLOSED_PERMANENTLY.",
      occurred_at: Time.current
    )
  end

  def add_rubro(business, rubro)
    business.rubros << rubro unless business.rubros.exists?(id: rubro.id)
  end
end
