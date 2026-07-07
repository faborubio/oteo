require "rails_helper"

RSpec.describe Rubro, type: :model do
  it "has a valid factory" do
    expect(build(:rubro)).to be_valid
  end

  it { is_expected.to have_many(:business_rubros).dependent(:destroy) }
  it { is_expected.to have_many(:businesses).through(:business_rubros) }

  it { is_expected.to validate_presence_of(:key) }
  it { is_expected.to validate_presence_of(:label) }
  it { is_expected.to validate_presence_of(:text_search_query) }

  it "requires a unique key" do
    create(:rubro, key: "restaurantes")
    expect(build(:rubro, key: "restaurantes")).not_to be_valid
  end

  it ".pos_targets returns only POS-target rubros" do
    target = create(:rubro, pos_target: true)
    other = create(:rubro, pos_target: false)

    expect(described_class.pos_targets).to include(target)
    expect(described_class.pos_targets).not_to include(other)
  end
end
