FactoryBot.define do
  factory :contact_event do
    business
    event_type { "nota" }
    product { "web" }
    body { "Llamé, pidió que volviera a contactar la próxima semana." }
    occurred_at { Time.current }
  end
end
