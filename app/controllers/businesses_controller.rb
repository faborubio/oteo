class BusinessesController < ApplicationController
  before_action :set_business, only: [ :show, :pos_status ]

  # Tabla filtrable ordenada por lead_score (SAD §7): el orden ES la estrategia.
  def index
    @comunas = Comuna.active.order(:name)
    @rubros = Rubro.active.order(:label)
    @pagy, @businesses = pagy(filtered_businesses, limit: 30)
  end

  def show
    @contact_events = @business.contact_events.limit(50)
    @contact_event = @business.contact_events.new
  end

  # Captura móvil de pos_status en 1 tap (ADR-004). El dato observado manda sobre la heurística.
  def pos_status
    status = params.dig(:business, :pos_status)
    if status.present? && !Business.pos_statuses.key?(status)
      return redirect_to @business, alert: "Estado POS inválido."
    end

    @business.assign_attributes(pos_status_params)

    if @business.save
      @business.contact_events.create!(
        event_type: "visita", product: "pos",
        body: "POS actualizado a “#{helpers.pos_status_label(@business.pos_status)}”" +
              (@business.pos_vendor.present? ? " (#{@business.pos_vendor})" : "")
      )
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to @business, notice: "POS actualizado." }
      end
    else
      redirect_to @business, alert: "No se pudo actualizar el POS."
    end
  end

  private

  def set_business
    @business = Business.includes(:comuna, :rubros).find(params[:id])
  end

  def pos_status_params
    params.require(:business).permit(:pos_status, :pos_vendor)
  end

  # Carril principal (con reputación) vs. "nuevos/sin reputación" (ADR-008): no compiten
  # en el mismo ranking. Filtros de comuna, presencia, pos_candidate y rubro.
  def filtered_businesses
    # La tabla solo muestra comuna (no rubros): includes(:comuna) evita N+1 sin chocar
    # con el joins(:rubros) del filtro por rubro (eager_load).
    scope = Business.includes(:comuna).active_pipeline

    scope = params[:lane] == "nuevos" ? scope.without_reputation : scope.with_reputation
    scope = scope.in_comuna(params[:comuna_id]) if params[:comuna_id].present?
    scope = scope.with_presence(params[:presence]) if params[:presence].present?
    scope = scope.pos_candidates if params[:pos_candidate] == "1"
    scope = scope.joins(:rubros).where(rubros: { id: params[:rubro_id] }) if params[:rubro_id].present?

    scope.by_score
  end
end
