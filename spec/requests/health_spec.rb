require "rails_helper"

RSpec.describe "Health", type: :request do
  let(:user) { create(:user) }
  let(:comuna) { create(:comuna, name: "Curicó") }
  let(:rubro) { create(:rubro) }

  before { sign_in(user) }

  it "muestra cuota, vencidos, fallidos y las últimas corridas" do
    create(:sync_run, comuna: comuna, rubro: rubro, status: "success", api_calls: 3, found_count: 20)
    create(:sync_run, comuna: comuna, rubro: rubro, status: "failed", api_calls: 1)
    create(:business, comuna: comuna, synced_at: 40.days.ago) # vencido

    get health_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Salud del sistema")
    expect(response.body).to include("Curicó × #{rubro.label}")
    expect(response.body).to include("Cuota Places")
  end

  it "cuenta las llamadas del mes en la cuota" do
    create(:sync_run, comuna: comuna, rubro: rubro, api_calls: 42, created_at: Time.current)

    get health_path

    expect(response.body).to include("42")
  end

  it "requiere autenticación" do
    delete session_path
    get health_path
    expect(response).to redirect_to(new_session_path)
  end
end
