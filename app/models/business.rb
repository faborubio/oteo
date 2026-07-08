class Business < ApplicationRecord
  # --- Enums (respaldados como string para legibilidad en la BD) ---

  # Origen del registro (ADR-012): Google no es el censo.
  enum :source, { places: "places", manual: "manual" }, default: "places"

  # Presencia digital en tres estados + web caída (ADR-003). nil = aún sin clasificar.
  enum :digital_presence, {
    sin_presencia: "sin_presencia",
    solo_redes: "solo_redes",
    web_propia: "web_propia",
    web_caida: "web_caida"
  }, prefix: :presence

  # Dato POS observado en terreno (ADR-004). Manda sobre la heurística pos_candidate.
  enum :pos_status, {
    desconocido: "desconocido",
    sin_sistema: "sin_sistema",
    caja_tradicional: "caja_tradicional",
    competidor: "competidor",
    usa_el_nuestro: "usa_el_nuestro"
  }, prefix: :pos, default: "desconocido"

  # Etapa del pipeline CRM (ADR-009); "archivado" lo pone el ciclo de vida (ADR-013).
  enum :pipeline_stage, {
    nuevo: "nuevo",
    contactado: "contactado",
    propuesta: "propuesta",
    cerrado: "cerrado",
    descartado: "descartado",
    archivado: "archivado"
  }, prefix: :stage, default: "nuevo"

  # businessStatus de Places (ADR-013). nil para negocios manuales sin ficha en Google.
  enum :business_status, {
    operational: "OPERATIONAL",
    closed_temporarily: "CLOSED_TEMPORARILY",
    closed_permanently: "CLOSED_PERMANENTLY"
  }, prefix: :status

  # --- Asociaciones ---
  belongs_to :comuna
  has_many :business_rubros, dependent: :destroy
  has_many :rubros, through: :business_rubros
  has_many :contact_events, -> { order(occurred_at: :desc) }, dependent: :destroy

  # --- Validaciones ---
  validates :name, presence: true
  validates :source, presence: true
  # place_id opcional (negocios manuales), pero único cuando existe (ADR-012).
  validates :place_id, uniqueness: true, allow_nil: true
  validates :user_rating_count, numericality: { greater_than_or_equal_to: 0 }

  # --- Scopes de dashboard y ciclo de vida ---
  scope :from_places, -> { where(source: "places") }
  scope :from_manual, -> { where(source: "manual") }
  scope :in_comuna, ->(comuna) { where(comuna: comuna) }
  scope :with_presence, ->(state) { where(digital_presence: state) }
  scope :pos_candidates, -> { where(pos_candidate: true) }
  scope :by_score, -> { order(lead_score: :desc) }

  # Carril principal vs. "nuevos/sin reputación" (ADR-008): los sin reseñas no
  # compiten en el mismo ranking, van a una vista aparte.
  scope :with_reputation, -> { where("user_rating_count > 0") }
  scope :without_reputation, -> { where(user_rating_count: 0) }

  # Kanban activo: los archivados (cerrados permanentemente) salen del tablero (ADR-013).
  scope :active_pipeline, -> { where.not(pipeline_stage: "archivado") }

  # Datos de Places vencidos (ADR-006): sincronizados hace más de la ventana ToS y
  # aún no expirados. El sync los refresca; el job de expiración (AUD-012) los nulifica.
  scope :places_stale, lambda {
    from_places.where(places_expired: false)
      .where(synced_at: ..Rails.configuration.oteo.places_retention_days.days.ago)
  }

  # El dato manual manda: si hay pos_status observado, la UI lo muestra (ADR-004).
  def pos_observed?
    !pos_desconocido?
  end
end
