# Carga config/oteo.yml (ADR-003 / ADR-006 / ADR-008) en Rails.configuration.oteo.
# Acceso: Rails.configuration.oteo.social_domains, .lead_score, .places_retention_days, etc.
Rails.application.configure do
  config.oteo = config_for(:oteo)
end
