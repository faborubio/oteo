require "rails_helper"

RSpec.describe BusinessClassifier do
  it "clasifica presencia, pos_candidate y lead_score de una vez" do
    business = build(
      :business,
      website_uri: nil,
      types: [ "restaurant", "food" ],
      user_rating_count: 213,
      digital_presence: nil,
      pos_candidate: false,
      lead_score: 0
    )

    described_class.classify(business)

    expect(business.digital_presence).to eq("sin_presencia")
    expect(business.pos_candidate).to be(true)
    expect(business.lead_score).to be_within(0.001).of(6.707)
  end

  it "una web propia con reseñas queda con score 0 (descartado como lead web)" do
    business = build(:business, website_uri: "https://minegocio.cl", types: [ "hair_care" ], user_rating_count: 300)

    described_class.classify(business)

    expect(business.digital_presence).to eq("web_propia")
    expect(business.pos_candidate).to be(false)
    expect(business.lead_score).to eq(0)
  end

  it "no toca los campos manuales (ADR-004)" do
    business = build(:business, pos_status: "usa_el_nuestro", pos_vendor: "Bsale", pipeline_stage: "propuesta")

    expect { described_class.classify(business) }
      .to not_change(business, :pos_status)
      .and not_change(business, :pos_vendor)
      .and not_change(business, :pipeline_stage)
  end
end
