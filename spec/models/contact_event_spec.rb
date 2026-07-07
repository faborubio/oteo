require "rails_helper"

RSpec.describe ContactEvent, type: :model do
  it "has a valid factory" do
    expect(build(:contact_event)).to be_valid
  end

  it { is_expected.to belong_to(:business) }
  it { is_expected.to validate_presence_of(:event_type) }

  it "sets occurred_at automatically on create" do
    event = create(:contact_event, occurred_at: nil)
    expect(event.occurred_at).to be_present
  end

  it "is append-only: cannot be modified once persisted" do
    event = create(:contact_event, body: "original")
    event.body = "editado"

    expect { event.save! }.to raise_error(ActiveRecord::ReadOnlyRecord)
  end
end
