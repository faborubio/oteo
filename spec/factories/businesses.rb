FactoryBot.define do
  factory :business do
    comuna
    source { "places" }
    sequence(:place_id) { |n| "ChIJ_place_#{n}" }
    sequence(:name) { |n| "Negocio #{n}" }
    address { "Calle Falsa 123" }
    lat { -35.4264 }
    lng { -71.6554 }
    phone { "+56 71 123 4567" }
    rating { 4.5 }
    user_rating_count { 120 }
    website_uri { "https://minegocio.cl" }
    types { [ "restaurant", "food" ] }
    business_status { "OPERATIONAL" }
    synced_at { Time.current }
    pos_candidate { true }
    lead_score { 12.5 }

    trait :sin_presencia do
      website_uri { nil }
      digital_presence { "sin_presencia" }
    end

    trait :solo_redes do
      website_uri { "https://instagram.com/minegocio" }
      digital_presence { "solo_redes" }
    end

    trait :web_propia do
      website_uri { "https://minegocio.cl" }
      digital_presence { "web_propia" }
    end

    trait :manual do
      source { "manual" }
      place_id { nil }
      business_status { nil }
      synced_at { nil }
    end

    trait :sin_reputacion do
      user_rating_count { 0 }
      rating { nil }
    end
  end
end
