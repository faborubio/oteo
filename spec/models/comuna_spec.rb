require "rails_helper"

RSpec.describe Comuna, type: :model do
  it "has a valid factory" do
    expect(build(:comuna)).to be_valid
  end

  it { is_expected.to have_many(:businesses).dependent(:restrict_with_error) }
  it { is_expected.to have_many(:sync_runs).dependent(:destroy) }

  it { is_expected.to validate_presence_of(:name) }

  it "requires a unique name" do
    create(:comuna, name: "Curicó")
    expect(build(:comuna, name: "Curicó")).not_to be_valid
  end

  it ".active returns only active comunas" do
    activa = create(:comuna, active: true)
    inactiva = create(:comuna, active: false)

    expect(described_class.active).to include(activa)
    expect(described_class.active).not_to include(inactiva)
  end
end
