FactoryBot.define do
  factory :comuna do
    sequence(:name) { |n| "Comuna #{n}" }
    region { "Maule" }
    active { true }
  end
end
