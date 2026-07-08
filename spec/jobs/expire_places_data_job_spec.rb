require "rails_helper"

RSpec.describe ExpirePlacesDataJob, type: :job do
  let(:window) { Rails.configuration.oteo.places_retention_days.days }

  it "nulifica los campos de Places de registros vencidos, conservando place_id y dato propio" do
    business = create(
      :business,
      place_id: "ChIJ_viejo", name: "Picada Antigua", synced_at: (window + 1.day).ago,
      website_uri: "https://x.cl", rating: 4.5, user_rating_count: 100, phone: "+56 9 1",
      pos_status: "usa_el_nuestro", pipeline_stage: "propuesta"
    )
    create(:contact_event, business: business, body: "nota propia")

    described_class.perform_now

    business.reload
    # Conserva place_id, identificación mínima y TODO el dato propio
    expect(business.place_id).to eq("ChIJ_viejo")
    expect(business.name).to eq("Picada Antigua")
    expect(business.pos_status).to eq("usa_el_nuestro")
    expect(business.pipeline_stage).to eq("propuesta")
    expect(business.contact_events.count).to eq(1)
    # Nulifica el contenido perecible de Places
    expect(business).to have_attributes(website_uri: nil, rating: nil, phone: nil, user_rating_count: 0)
    expect(business.places_expired).to be(true)
  end

  it "no toca registros dentro de la ventana de retención" do
    fresco = create(:business, synced_at: 1.day.ago, website_uri: "https://y.cl")

    described_class.perform_now

    expect(fresco.reload.website_uri).to eq("https://y.cl")
    expect(fresco.places_expired).to be(false)
  end

  it "no toca negocios manuales (no vienen de Places)" do
    manual = create(:business, :manual, synced_at: nil, website_uri: "https://propia.cl")

    described_class.perform_now

    expect(manual.reload.website_uri).to eq("https://propia.cl")
  end

  it "es idempotente: un registro ya expirado no se reprocesa" do
    create(:business, synced_at: (window + 1.day).ago, website_uri: "https://z.cl")

    expect(described_class.perform_now).to eq(1)
    expect(described_class.perform_now).to eq(0)
  end
end
