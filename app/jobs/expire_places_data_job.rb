# Cumplimiento ToS (ADR-006 / AUD-012): borra el contenido de Places de los registros
# no refrescados dentro de la ventana de retención (30 días). Solo `place_id` puede
# guardarse indefinidamente; el resto del contenido perecible debe borrarse.
#
# Se conserva: place_id, comuna, nombre/dirección (identificación mínima del lead
# operativo) y TODO el dato propio (pos_status, pipeline_stage, contact_events,
# clasificación derivada). Se nulifican los campos crudos de Places.
#
# Un negocio que reaparezca en un sync se repuebla y `places_expired` vuelve a false.
class ExpirePlacesDataJob < ApplicationJob
  queue_as :default

  PERISHABLE_DEFAULTS = {
    lat: nil, lng: nil, phone: nil, rating: nil,
    user_rating_count: 0, website_uri: nil, types: [],
    business_status: nil, places_expired: true
  }.freeze

  def perform
    count = Business.places_stale.update_all(PERISHABLE_DEFAULTS.merge(updated_at: Time.current))
    Rails.logger.info("ExpirePlacesDataJob: #{count} negocios con datos de Places expirados (ToS 30 días).")
    count
  end
end
