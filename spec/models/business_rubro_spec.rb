require "rails_helper"

RSpec.describe BusinessRubro, type: :model do
  it "has a valid factory" do
    expect(build(:business_rubro)).to be_valid
  end

  it { is_expected.to belong_to(:business) }
  it { is_expected.to belong_to(:rubro) }

  it "does not duplicate the same rubro for a business (ADR-013: agrega, no repite)" do
    business = create(:business)
    rubro = create(:rubro)
    create(:business_rubro, business: business, rubro: rubro)

    expect(build(:business_rubro, business: business, rubro: rubro)).not_to be_valid
  end

  it "allows the same rubro across different businesses" do
    rubro = create(:rubro)
    create(:business_rubro, business: create(:business), rubro: rubro)

    expect(build(:business_rubro, business: create(:business), rubro: rubro)).to be_valid
  end
end
