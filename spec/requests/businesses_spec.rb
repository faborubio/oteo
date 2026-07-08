require "rails_helper"

RSpec.describe "Businesses", type: :request do
  let(:user) { create(:user) }
  let(:comuna) { create(:comuna, name: "Curicó") }

  before { sign_in(user) }

  describe "GET /businesses (tabla filtrable)" do
    it "renderiza la tabla ordenada por score con negocios con reputación" do
      create(:business, :web_propia, name: "Alta", comuna: comuna, user_rating_count: 100, lead_score: 9)
      create(:business, :sin_presencia, name: "Baja", comuna: comuna, user_rating_count: 100, lead_score: 1)

      get businesses_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Alta").and include("Baja")
      expect(response.body.index("Alta")).to be < response.body.index("Baja") # score desc
    end

    it "el carril por defecto excluye negocios sin reputación (ADR-008)" do
      create(:business, name: "Con reseñas", comuna: comuna, user_rating_count: 50)
      create(:business, :sin_reputacion, name: "Sin reseñas", comuna: comuna)

      get businesses_path

      expect(response.body).to include("Con reseñas")
      expect(response.body).not_to include("Sin reseñas")
    end

    it "el carril 'nuevos' muestra solo los sin reputación" do
      create(:business, name: "Con reseñas", comuna: comuna, user_rating_count: 50)
      create(:business, :sin_reputacion, name: "Sin reseñas", comuna: comuna)

      get businesses_path(lane: "nuevos")

      expect(response.body).to include("Sin reseñas")
      expect(response.body).not_to include("Con reseñas")
    end

    it "filtra por presencia digital" do
      create(:business, :sin_presencia, name: "SinWeb", comuna: comuna, user_rating_count: 30)
      create(:business, :web_propia, name: "ConWeb", comuna: comuna, user_rating_count: 30)

      get businesses_path(presence: "sin_presencia")

      expect(response.body).to include("SinWeb")
      expect(response.body).not_to include("ConWeb")
    end

    it "filtra por candidato POS" do
      create(:business, name: "EsPOS", comuna: comuna, user_rating_count: 30, pos_candidate: true)
      create(:business, name: "NoPOS", comuna: comuna, user_rating_count: 30, pos_candidate: false)

      get businesses_path(pos_candidate: "1")

      expect(response.body).to include("EsPOS")
      expect(response.body).not_to include("NoPOS")
    end

    it "filtra por rubro sin duplicar filas (negocio multi-rubro)" do
      rubro = create(:rubro, key: "botillerias", label: "Botillerías")
      otro = create(:rubro, key: "farmacias", label: "Farmacias")
      con_rubro = create(:business, name: "Botillería Central", comuna: comuna, user_rating_count: 30)
      con_rubro.rubros << [ rubro, otro ] # multi-rubro
      create(:business, name: "Otra cosa", comuna: comuna, user_rating_count: 30)

      get businesses_path(rubro_id: rubro.id)

      expect(response.body).to include("Botillería Central")
      expect(response.body).not_to include("Otra cosa")
      expect(response.body.scan("Botillería Central").size).to eq(1) # sin duplicados por el join
    end

    it "excluye negocios archivados del listado (ADR-013)" do
      create(:business, name: "Activo", comuna: comuna, user_rating_count: 30)
      create(:business, name: "Archivado", comuna: comuna, user_rating_count: 30, pipeline_stage: "archivado")

      get businesses_path

      expect(response.body).to include("Activo")
      expect(response.body).not_to include("Archivado")
    end
  end

  describe "GET /businesses/map (mapa)" do
    around do |example|
      old = ENV["GOOGLE_MAPS_JS_API_KEY"]
      ENV["GOOGLE_MAPS_JS_API_KEY"] = "test-map-key"
      example.run
      ENV["GOOGLE_MAPS_JS_API_KEY"] = old
    end

    it "plotea solo negocios con coordenadas" do
      con = create(:business, name: "ConCoord", comuna: comuna, user_rating_count: 20, lat: -34.98, lng: -71.23)
      create(:business, name: "SinCoord", comuna: comuna, user_rating_count: 20, lat: nil, lng: nil)

      get map_businesses_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("ConCoord")
      expect(response.body).not_to include("SinCoord")
      expect(response.body).to include("data-controller=\"map\"")
    end

    it "muestra ambos carriles (con y sin reputación) en el mapa" do
      create(:business, name: "ConRep", comuna: comuna, user_rating_count: 80, lat: -34.98, lng: -71.23)
      create(:business, :sin_reputacion, name: "SinRep", comuna: comuna, lat: -34.99, lng: -71.24)

      get map_businesses_path

      expect(response.body).to include("ConRep").and include("SinRep")
    end

    it "filtra por comuna" do
      otra = create(:comuna, name: "Molina")
      create(:business, name: "EnCurico", comuna: comuna, user_rating_count: 20, lat: -34.98, lng: -71.23)
      create(:business, name: "EnMolina", comuna: otra, user_rating_count: 20, lat: -35.11, lng: -71.28)

      get map_businesses_path(comuna_id: comuna.id)

      expect(response.body).to include("EnCurico")
      expect(response.body).not_to include("EnMolina")
    end

    it "sin key configurada muestra el fallback, no el mapa" do
      # Sin key desde NINGUNA fuente (ENV ni credentials). Se stubea el helper para no depender
      # de si hay una key real cargada en credentials del entorno.
      allow_any_instance_of(ApplicationHelper).to receive(:google_maps_api_key).and_return(nil)
      create(:business, comuna: comuna, user_rating_count: 20, lat: -34.98, lng: -71.23)

      get map_businesses_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Falta la")
      expect(response.body).not_to include("data-controller=\"map\"")
    end
  end

  describe "GET /businesses/:id (ficha)" do
    it "muestra el guion de venta según el estado de presencia (ADR-003)" do
      business = create(:business, :sin_presencia, comuna: comuna, user_rating_count: 40)

      get business_path(business)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Ángulo de venta")
      expect(response.body).to include("visibilidad")
    end
  end

  describe "PATCH /businesses/:id/pos_status (captura móvil, ADR-004)" do
    it "actualiza el pos_status y registra un contact_event" do
      business = create(:business, comuna: comuna, pos_status: "desconocido")

      expect {
        patch pos_status_business_path(business),
              params: { business: { pos_status: "usa_el_nuestro", pos_vendor: "Oteo POS" } },
              as: :turbo_stream
      }.to change { business.contact_events.count }.by(1)

      expect(response.media_type).to eq(Mime[:turbo_stream])
      expect(business.reload).to have_attributes(pos_status: "usa_el_nuestro", pos_vendor: "Oteo POS")
    end

    it "rechaza un pos_status inválido sin reventar (guard de enum)" do
      business = create(:business, comuna: comuna, pos_status: "desconocido")

      patch pos_status_business_path(business), params: { business: { pos_status: "hackeado" } }

      expect(response).to redirect_to(business_path(business))
      expect(business.reload.pos_status).to eq("desconocido")
    end
  end

  describe "sin autenticar" do
    it "redirige al login" do
      # sobrescribe el before(sign_in) cerrando sesión
      delete session_path
      get businesses_path
      expect(response).to redirect_to(new_session_path)
    end
  end
end
