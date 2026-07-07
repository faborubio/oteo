class SyncRun < ApplicationRecord
  # Tablero de salud de la cuota (SAD §8): cada corrida audita llamadas y resultados.
  enum :status, {
    pending: "pending",
    running: "running",
    success: "success",
    failed: "failed"
  }, default: "pending"

  belongs_to :comuna
  belongs_to :rubro

  scope :recent, -> { order(created_at: :desc) }

  # Llamadas consumidas este mes vs. cupo del SKU (ADR-002): el driver #2 manda.
  def self.api_calls_this_month
    where(created_at: Time.current.beginning_of_month..).sum(:api_calls)
  end
end
