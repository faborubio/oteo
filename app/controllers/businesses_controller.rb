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

  # Negocio de origen manual (ADR-012): Google no es el censo. Los socios en terreno
  # agregan lo que Places no lista; parte con 0 reseñas → carril "nuevos".
  def new
    @business = Business.new(source: "manual")
    @comunas = Comuna.active.order(:name)
    @rubros = Rubro.active.order(:label)
  end

  def create
    @business = Business.new(business_params.merge(source: "manual"))
    BusinessClassifier.classify(@business)

    if @business.save
      @business.contact_events.create!(
        event_type: "sistema",
        body: "Negocio agregado manualmente (no estaba en Google Places)."
      )
      redirect_to @business, notice: "Negocio agregado al pipeline."
    else
      @comunas = Comuna.active.order(:name)
      @rubros = Rubro.active.order(:label)
      render :new, status: :unprocessable_content
    end
  end

  # Tercera vista: mapa (Google Maps JS — ADR-007/AUD-002). Muestra todos los leads que
  # matchean el filtro (ambos carriles) con coordenadas. JSON acotado al filtro (NFR §9).
  def map
    @comunas = Comuna.active.order(:name)
    @rubros = Rubro.active.order(:label)
    businesses = apply_filters(Business.includes(:comuna).active_pipeline)
                   .where.not(lat: nil).where.not(lng: nil).by_score.limit(500)
    @markers = businesses.map do |b|
      {
        id: b.id, name: b.name, lat: b.lat.to_f, lng: b.lng.to_f,
        presence: b.digital_presence, comuna: b.comuna.name,
        score: b.lead_score.to_f, url: business_path(b)
      }
    end
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

  def business_params
    params.require(:business).permit(:name, :comuna_id, :address, :phone, :website_uri, rubro_ids: [])
  end

  # Carril principal (con reputación) vs. "nuevos/sin reputación" (ADR-008): no compiten
  # en el mismo ranking. La tabla usa el carril; el mapa muestra ambos.
  # Con búsqueda por nombre los carriles se cruzan: buscar es un lookup, no un ranking —
  # "no aparece porque está en el otro carril" sería un falso negativo confuso.
  def filtered_businesses
    scope = if params[:q].present?
      Business.all
    else
      params[:lane] == "nuevos" ? Business.without_reputation : Business.with_reputation
    end
    apply_filters(scope.includes(:comuna).active_pipeline).by_score
  end

  # Filtros compartidos por tabla y mapa: comuna, presencia, pos_candidate, rubro y nombre.
  # includes(:comuna) evita N+1 sin chocar con el joins(:rubros) del filtro por rubro.
  def apply_filters(scope)
    scope = scope.search_name(params[:q]) if params[:q].present?
    scope = scope.in_comuna(params[:comuna_id]) if params[:comuna_id].present?
    scope = scope.with_presence(params[:presence]) if params[:presence].present?
    scope = scope.pos_candidates if params[:pos_candidate] == "1"
    scope = scope.joins(:rubros).where(rubros: { id: params[:rubro_id] }) if params[:rubro_id].present?
    scope
  end
end
