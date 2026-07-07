class ContactEvent < ApplicationRecord
  # Historial por negocio (SAD §6): inmutable, append-only.
  enum :event_type, {
    llamada: "llamada",
    visita: "visita",
    whatsapp: "whatsapp",
    email: "email",
    nota: "nota",
    cambio_etapa: "cambio_etapa",
    sistema: "sistema"
  }, prefix: :event

  enum :product, { web: "web", pos: "pos", ambos: "ambos" }, prefix: :product

  belongs_to :business

  validates :event_type, presence: true
  validates :occurred_at, presence: true

  before_validation :set_occurred_at, on: :create

  scope :chronological, -> { order(occurred_at: :asc) }

  # Append-only: una vez creado, no se edita ni borra su contenido.
  def readonly?
    persisted?
  end

  private

  def set_occurred_at
    self.occurred_at ||= Time.current
  end
end
