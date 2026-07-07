require "rails_helper"

RSpec.describe Business, type: :model do
  it "has a valid factory" do
    expect(build(:business)).to be_valid
  end

  describe "associations" do
    it { is_expected.to belong_to(:comuna) }
    it { is_expected.to have_many(:business_rubros).dependent(:destroy) }
    it { is_expected.to have_many(:rubros).through(:business_rubros) }
    it { is_expected.to have_many(:contact_events).dependent(:destroy) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }

    it "allows a nil place_id (negocios manuales — ADR-012)" do
      expect(build(:business, :manual, place_id: nil)).to be_valid
    end

    it "enforces uniqueness of place_id only when present" do
      create(:business, place_id: "ChIJ_dup")
      expect(build(:business, place_id: "ChIJ_dup")).not_to be_valid
    end

    it "permits many manual businesses without place_id" do
      create(:business, :manual, place_id: nil)
      expect(build(:business, :manual, place_id: nil)).to be_valid
    end
  end

  describe "enums" do
    it { is_expected.to define_enum_for(:source).with_values(places: "places", manual: "manual").backed_by_column_of_type(:string) }
    it { is_expected.to define_enum_for(:digital_presence).with_values(sin_presencia: "sin_presencia", solo_redes: "solo_redes", web_propia: "web_propia", web_caida: "web_caida").with_prefix(:presence).backed_by_column_of_type(:string) }
    it { is_expected.to define_enum_for(:pipeline_stage).with_prefix(:stage).backed_by_column_of_type(:string) }
  end

  describe "defaults" do
    subject(:business) { described_class.new }

    it { expect(business.source).to eq("places") }
    it { expect(business.pos_status).to eq("desconocido") }
    it { expect(business.pipeline_stage).to eq("nuevo") }
    it { expect(business.pos_candidate).to be(false) }
    it { expect(business.lead_score).to eq(0) }
  end

  describe "#pos_observed?" do
    it "is false when pos_status is desconocido" do
      expect(build(:business, pos_status: "desconocido").pos_observed?).to be(false)
    end

    it "is true once observed in the field (ADR-004)" do
      expect(build(:business, pos_status: "sin_sistema").pos_observed?).to be(true)
    end
  end

  describe "scopes" do
    it ".with_reputation / .without_reputation split the ranking (ADR-008)" do
      con = create(:business, user_rating_count: 50)
      sin = create(:business, :sin_reputacion)

      expect(described_class.with_reputation).to contain_exactly(con)
      expect(described_class.without_reputation).to contain_exactly(sin)
    end

    it ".active_pipeline excludes archived businesses (ADR-013)" do
      activo = create(:business, pipeline_stage: "nuevo")
      archivado = create(:business, pipeline_stage: "archivado")

      expect(described_class.active_pipeline).to include(activo)
      expect(described_class.active_pipeline).not_to include(archivado)
    end

    it ".by_score orders by lead_score descending" do
      low = create(:business, lead_score: 1)
      high = create(:business, lead_score: 99)

      expect(described_class.by_score.first).to eq(high)
      expect(described_class.by_score.last).to eq(low)
    end
  end
end
