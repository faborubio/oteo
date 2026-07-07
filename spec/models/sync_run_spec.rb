require "rails_helper"

RSpec.describe SyncRun, type: :model do
  it "has a valid factory" do
    expect(build(:sync_run)).to be_valid
  end

  it { is_expected.to belong_to(:comuna) }
  it { is_expected.to belong_to(:rubro) }

  it "defaults to pending status" do
    expect(described_class.new.status).to eq("pending")
  end

  describe ".api_calls_this_month" do
    it "sums api_calls within the current month only (ADR-002 quota counter)" do
      create(:sync_run, api_calls: 5, created_at: Time.current)
      create(:sync_run, api_calls: 3, created_at: Time.current.beginning_of_month + 1.hour)
      create(:sync_run, api_calls: 99, created_at: 2.months.ago)

      expect(described_class.api_calls_this_month).to eq(8)
    end
  end
end
