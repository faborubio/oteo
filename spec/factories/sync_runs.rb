FactoryBot.define do
  factory :sync_run do
    comuna
    rubro
    query { "restaurantes en Curicó, Chile" }
    status { "success" }
    started_at { 1.minute.ago }
    finished_at { Time.current }
    found_count { 42 }
    new_count { 10 }
    updated_count { 32 }
    error_count { 0 }
    api_calls { 3 }
  end
end
