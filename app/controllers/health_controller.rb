# Página de salud interna (SAD §8): el tablero de operación de un solo dev.
# Cuota consumida vs cupo, datos vencidos por ToS, jobs fallidos y últimas corridas.
class HealthController < ApplicationController
  def show
    @api_calls_month = SyncRun.api_calls_this_month
    @quota = Rails.configuration.oteo.places_monthly_quota
    @quota_pct = @quota.positive? ? (100.0 * @api_calls_month / @quota).round(1) : 0

    @stale_count = Business.places_stale.count
    @expired_count = Business.from_places.where(places_expired: true).count
    @failed_runs = SyncRun.where(status: "failed").where(created_at: 1.month.ago..).count

    @total_businesses = Business.count
    @by_presence = Business.group(:digital_presence).count
    @recent_runs = SyncRun.includes(:comuna, :rubro).recent.limit(15)
  end
end
