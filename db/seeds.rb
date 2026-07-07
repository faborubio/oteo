# Seed idempotente: usuario único + taxonomías objetivo (SAD Fase 0).
# Ejecutable en cualquier momento sin duplicar (find_or_create_by!).

# --- Usuario único (herramienta interna, un solo dev) ---
if (email = ENV["OTEO_ADMIN_EMAIL"]) && (password = ENV["OTEO_ADMIN_PASSWORD"])
  User.find_or_create_by!(email_address: email) do |user|
    user.password = password
  end
  puts "✔ Usuario #{email} listo"
else
  puts "⚠ Define OTEO_ADMIN_EMAIL y OTEO_ADMIN_PASSWORD para sembrar el usuario"
end

# --- Comunas objetivo del Maule (6) ---
comunas = [
  "Talca",
  "Curicó",
  "Constitución",
  "Curepto",
  "Molina",
  "San Clemente"
]
comunas.each { |name| Comuna.find_or_create_by!(name: name) { |c| c.region = "Maule" } }
puts "✔ #{Comuna.count} comunas"

# --- Rubros objetivo (8) con su query de Text Search y flag pos_target (ADR-004) ---
rubros = [
  { key: "restaurantes",  label: "Restaurantes",  query: "restaurantes",       pos_target: true },
  { key: "minimarkets",   label: "Minimarkets",   query: "minimarket",         pos_target: true },
  { key: "botillerias",   label: "Botillerías",   query: "botillería",         pos_target: true },
  { key: "farmacias",     label: "Farmacias",     query: "farmacia",           pos_target: true },
  { key: "panaderias",    label: "Panaderías",    query: "panadería",          pos_target: true },
  { key: "cafeterias",    label: "Cafeterías",    query: "cafetería",          pos_target: true },
  { key: "ferreterias",   label: "Ferreterías",   query: "ferretería",         pos_target: false },
  { key: "peluquerias",   label: "Peluquerías",   query: "peluquería",         pos_target: false }
]
rubros.each do |attrs|
  Rubro.find_or_create_by!(key: attrs[:key]) do |r|
    r.label = attrs[:label]
    r.text_search_query = attrs[:query]
    r.pos_target = attrs[:pos_target]
  end
end
puts "✔ #{Rubro.count} rubros (#{Rubro.pos_targets.count} candidatos POS)"

puts "→ #{Comuna.active.count} × #{Rubro.active.count} = #{Comuna.active.count * Rubro.active.count} combinaciones de sync"
