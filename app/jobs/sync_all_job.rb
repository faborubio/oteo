# Encola un SyncJob por cada combinación activa comuna × rubro (ADR-005). Lo dispara
# el schedule quincenal de Solid Queue (config/recurring.yml) o `rake oteo:sync_all`.
# Concurrencia limitada de workers respeta el rate limit de Places (SAD §8).
class SyncAllJob < ApplicationJob
  queue_as :default

  def perform
    combos = Comuna.active.flat_map { |comuna| Rubro.active.map { |rubro| [ comuna, rubro ] } }
    combos.each { |comuna, rubro| SyncJob.perform_later(comuna.id, rubro.id) }
    Rails.logger.info("SyncAllJob: encoladas #{combos.size} combinaciones (comuna × rubro).")
    combos.size
  end
end
