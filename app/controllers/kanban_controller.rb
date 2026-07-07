class KanbanController < ApplicationController
  # Columnas activas del pipeline (ADR-009). "archivado" no es columna: sale del tablero.
  BOARD_STAGES = %w[nuevo contactado propuesta cerrado descartado].freeze

  def index
    @stages = BOARD_STAGES
    @cards = Business.active_pipeline.includes(:comuna).by_score.group_by(&:pipeline_stage)
  end

  # Mover una tarjeta cambia pipeline_stage y deja un contact_event (ADR-009):
  # cada movimiento queda en el historial.
  def update
    @business = Business.find(params[:id])
    stage = params[:stage].to_s

    unless BOARD_STAGES.include?(stage)
      return respond_to do |format|
        format.turbo_stream { head :unprocessable_content }
        format.html { redirect_to kanban_path, alert: "Etapa inválida." }
      end
    end

    from = @business.pipeline_stage
    @business.update!(pipeline_stage: stage)
    @business.contact_events.create!(
      event_type: "cambio_etapa",
      body: "#{helpers.stage_label(from)} → #{helpers.stage_label(stage)}"
    ) if from != stage

    respond_to do |format|
      format.turbo_stream { head :ok }
      format.html { redirect_to kanban_path, notice: "Movido a #{helpers.stage_label(stage)}." }
    end
  end
end
