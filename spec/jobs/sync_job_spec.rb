require "rails_helper"

RSpec.describe SyncJob, type: :job do
  let(:comuna) { create(:comuna, name: "Curicó") }
  let(:rubro) { create(:rubro, key: "restaurantes", text_search_query: "restaurantes", pos_target: true) }

  def snapshot(**overrides)
    defaults = {
      place_id: "ChIJ_#{SecureRandom.hex(4)}",
      name: "Fuente de Soda El Rápido",
      address: "Yungay 123, Curicó",
      lat: -34.9854, lng: -71.2394,
      phone: "+56 75 231 4455",
      rating: 4.6, user_rating_count: 213,
      website_uri: nil,
      types: [ "restaurant", "food" ],
      business_status: "OPERATIONAL"
    }
    PlacesClient::Snapshot.new(**defaults.merge(overrides))
  end

  def result(*snaps, api_calls: 1, error: nil)
    PlacesClient::Result.new(snapshots: snaps, api_calls: api_calls, error: error)
  end

  def run_sync(res, comuna: self.comuna, rubro: self.rubro)
    allow(PlacesClient).to receive(:search).and_return(res)
    described_class.perform_now(comuna.id, rubro.id)
  end

  describe "sync exitoso" do
    it "crea negocios, los clasifica y registra el SyncRun con contadores y api_calls" do
      res = result(snapshot(website_uri: nil), snapshot(website_uri: "https://instagram.com/x"), api_calls: 2)

      sync_run = run_sync(res)

      expect(Business.count).to eq(2)
      expect(sync_run).to have_attributes(status: "success", found_count: 2, new_count: 2, updated_count: 0, api_calls: 2)
      expect(sync_run.finished_at).to be_present

      lead = Business.find_by(website_uri: nil)
      expect(lead.digital_presence).to eq("sin_presencia")
      expect(lead.pos_candidate).to be(true)
      expect(lead.lead_score).to be > 0
    end

    it "asigna la comuna de la consulta de origen y el rubro buscado (ADR-013)" do
      run_sync(result(snapshot))
      business = Business.last

      expect(business.comuna).to eq(comuna)
      expect(business.rubros).to contain_exactly(rubro)
    end
  end

  describe "idempotencia (SAD §8)" do
    it "re-ejecutar no duplica filas ni rubros; cuenta como actualizado" do
      res = result(snapshot)

      run_sync(res)
      second = run_sync(res)

      expect(Business.count).to eq(1)
      expect(BusinessRubro.count).to eq(1)
      expect(second).to have_attributes(new_count: 0, updated_count: 1)
    end
  end

  describe "respeto de campos manuales (ADR-004)" do
    it "no toca pos_status, pos_vendor ni pipeline_stage al re-sincronizar" do
      res = result(snapshot)
      run_sync(res)

      business = Business.last
      business.update!(pos_status: "usa_el_nuestro", pos_vendor: "Bsale", pipeline_stage: "propuesta")

      run_sync(res)

      expect(business.reload).to have_attributes(
        pos_status: "usa_el_nuestro", pos_vendor: "Bsale", pipeline_stage: "propuesta"
      )
    end
  end

  describe "multi-rubro (ADR-013: agrega, no reemplaza)" do
    it "un negocio encontrado en dos rubros acumula ambos sin flapping" do
      snap = snapshot
      otro_rubro = create(:rubro, key: "minimarkets", text_search_query: "minimarket")

      run_sync(result(snap), rubro: rubro)
      run_sync(result(snap), rubro: otro_rubro)

      expect(Business.count).to eq(1)
      expect(Business.last.rubros).to contain_exactly(rubro, otro_rubro)
    end

    it "no cambia la comuna de origen aunque otro sync lo encuentre en otra comuna" do
      snap = snapshot
      otra_comuna = create(:comuna, name: "Molina")

      run_sync(result(snap), comuna: comuna)
      run_sync(result(snap), comuna: otra_comuna)

      expect(Business.last.comuna).to eq(comuna)
    end
  end

  describe "ciclo de vida: cierre permanente (ADR-013)" do
    it "archiva y registra un evento de sistema, una sola vez" do
      res = result(snapshot(business_status: "CLOSED_PERMANENTLY"))

      run_sync(res)
      business = Business.last

      expect(business.pipeline_stage).to eq("archivado")
      expect(business.contact_events.where(event_type: "sistema").count).to eq(1)

      run_sync(res) # re-sync no debe duplicar el evento
      expect(business.reload.contact_events.where(event_type: "sistema").count).to eq(1)
    end
  end

  describe "casos borde de ingesta (auditoría vista de halcón)" do
    it "omite snapshots sin place_id y NO pisa un negocio manual (place_id nil)" do
      manual = create(:business, :manual, name: "Almacén de la esquina", pos_status: "usa_el_nuestro")

      sync_run = run_sync(result(snapshot(place_id: ""), snapshot(place_id: nil), api_calls: 1))

      expect(Business.count).to eq(1) # solo el manual; nada nuevo creado
      expect(manual.reload).to have_attributes(name: "Almacén de la esquina", pos_status: "usa_el_nuestro")
      expect(sync_run).to have_attributes(found_count: 2, new_count: 0, error_count: 2)
    end

    it "un registro inválido no tumba el batch: los demás se procesan" do
      res = result(snapshot(name: nil), snapshot(name: "Válido"), api_calls: 1)

      sync_run = run_sync(res)

      expect(Business.count).to eq(1)
      expect(Business.last.name).to eq("Válido")
      expect(sync_run).to have_attributes(found_count: 2, new_count: 1, error_count: 1)
    end
  end

  describe "manejo de errores de cuota (driver #2)" do
    it "marca el SyncRun como fallido y NO reintenta (no lanza)" do
      res = result(api_calls: 1, error: "HTTP 429: RESOURCE_EXHAUSTED")

      expect { @sync_run = run_sync(res) }.not_to raise_error
      expect(@sync_run).to have_attributes(status: "failed", api_calls: 1)
      expect(@sync_run.notes).to include("CUOTA AGOTADA")
      expect(Business.count).to eq(0)
    end

    it "un error transitorio marca fallido y encola un reintento (retry_on con backoff)" do
      res = result(api_calls: 1, error: "Net::ReadTimeout: timeout")
      allow(PlacesClient).to receive(:search).and_return(res)

      expect { described_class.perform_now(comuna.id, rubro.id) }
        .to have_enqueued_job(SyncJob)

      expect(SyncRun.last).to have_attributes(status: "failed", api_calls: 1)
    end
  end
end
