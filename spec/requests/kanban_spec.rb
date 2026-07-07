require "rails_helper"

RSpec.describe "Kanban", type: :request do
  let(:user) { create(:user) }
  let(:comuna) { create(:comuna) }

  before { sign_in(user) }

  describe "GET /kanban" do
    it "renderiza el tablero agrupado por etapa, sin archivados (ADR-013)" do
      create(:business, name: "EnNuevo", comuna: comuna, pipeline_stage: "nuevo", user_rating_count: 10)
      create(:business, name: "Archivado", comuna: comuna, pipeline_stage: "archivado", user_rating_count: 10)

      get kanban_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("EnNuevo")
      expect(response.body).not_to include("Archivado")
    end
  end

  describe "PATCH /kanban/:id (mover tarjeta)" do
    it "cambia el pipeline_stage y registra un contact_event (ADR-009)" do
      business = create(:business, comuna: comuna, pipeline_stage: "nuevo")

      expect {
        patch kanban_business_path(business), params: { stage: "contactado" }, as: :turbo_stream
      }.to change { business.contact_events.where(event_type: "cambio_etapa").count }.by(1)

      expect(response).to have_http_status(:ok)
      expect(business.reload.pipeline_stage).to eq("contactado")
    end

    it "rechaza una etapa inválida sin cambiar nada" do
      business = create(:business, comuna: comuna, pipeline_stage: "nuevo")

      patch kanban_business_path(business), params: { stage: "inventada" }, as: :turbo_stream

      expect(response).to have_http_status(:unprocessable_content)
      expect(business.reload.pipeline_stage).to eq("nuevo")
    end

    it "no registra evento si la etapa no cambia" do
      business = create(:business, comuna: comuna, pipeline_stage: "nuevo")

      expect {
        patch kanban_business_path(business), params: { stage: "nuevo" }, as: :turbo_stream
      }.not_to change { business.contact_events.count }
    end
  end
end
