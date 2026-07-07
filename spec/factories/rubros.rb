FactoryBot.define do
  factory :rubro do
    sequence(:key) { |n| "rubro_#{n}" }
    label { "Restaurantes" }
    text_search_query { "restaurantes" }
    pos_target { true }
    active { true }
  end
end
