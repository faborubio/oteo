namespace :oteo do
  # Busca la comuna sin depender de acentos ni mayúsculas: "curico" == "Curicó".
  def find_comuna!(name)
    target = I18n.transliterate(name.to_s).downcase.strip
    Comuna.all.detect { |c| I18n.transliterate(c.name).downcase == target } ||
      raise(ActiveRecord::RecordNotFound, "Comuna no encontrada: #{name.inspect}")
  end

  desc "Encola un sync de una combinación: rake 'oteo:sync_one[curico,restaurantes]'"
  task :sync_one, [ :comuna, :rubro ] => :environment do |_t, args|
    comuna = find_comuna!(args[:comuna])
    rubro = Rubro.find_by!(key: args[:rubro])
    SyncJob.perform_later(comuna.id, rubro.id)
    puts "→ Encolado SyncJob(#{comuna.name} × #{rubro.label})"
  end

  desc "Encola el sync de TODAS las combinaciones activas (comuna × rubro)"
  task sync_all: :environment do
    combos = Comuna.active.flat_map { |c| Rubro.active.map { |r| [ c, r ] } }
    combos.each { |comuna, rubro| SyncJob.perform_later(comuna.id, rubro.id) }
    puts "→ Encoladas #{combos.size} combinaciones. Cuota usada este mes: #{SyncRun.api_calls_this_month} llamadas."
  end

  desc "Audita a mano la clasificación de los últimos negocios sincronizados (SAD §10)"
  task :audit, [ :limit ] => :environment do |_t, args|
    n = (args[:limit] || 20).to_i
    businesses = Business.from_places.where.not(synced_at: nil).order(synced_at: :desc).limit(n)

    if businesses.empty?
      puts "No hay negocios sincronizados. Corre primero: rake 'oteo:sync_now[curico,restaurantes]'"
      next
    end

    puts "Auditoría de #{businesses.size} negocios (señal cruda → veredicto del clasificador):\n\n"
    businesses.each do |b|
      puts "• #{b.name}  [#{b.comuna.name}]  ⭐#{b.rating || '—'} (#{b.user_rating_count} reseñas)"
      puts "  website_uri: #{b.website_uri.presence || '(vacío)'}"
      puts "  → presencia: #{b.digital_presence}   pos_candidate: #{b.pos_candidate}   score: #{b.lead_score}"
      puts "  types: #{b.types.join(', ')}"
      puts ""
    end
    puts "¿Algún website_uri mal clasificado? Documenta el caso en docs/CASES.md antes de tocar config/oteo.yml."
  end

  desc "Genera negocios de demo (solo dev) para ver las tres vistas sin la API de Places"
  task demo_data: :environment do
    raise "Solo en development" unless Rails.env.development?

    require "faker"
    comunas = Comuna.active.to_a
    rubros = Rubro.active.to_a
    presences = %w[sin_presencia solo_redes web_propia]
    stages = %w[nuevo nuevo nuevo contactado propuesta cerrado]

    30.times do
      comuna = comunas.sample
      presence = presences.sample
      count = [ 0, rand(5..400) ].sample
      business = Business.create!(
        source: "places", place_id: "demo_#{SecureRandom.hex(5)}",
        name: Faker::Company.name, address: Faker::Address.street_address,
        comuna: comuna, lat: -35.4 + rand(-0.4..0.4), lng: -71.6 + rand(-0.4..0.4),
        phone: "+56 9 #{rand(1000..9999)} #{rand(1000..9999)}",
        rating: (rand(30..50) / 10.0), user_rating_count: count,
        website_uri: presence == "sin_presencia" ? nil : "https://ejemplo.cl",
        types: [ "restaurant" ], business_status: "OPERATIONAL",
        pipeline_stage: stages.sample
      )
      business.rubros << rubros.sample
      BusinessClassifier.classify(business)
      business.save!
    end
    puts "→ #{Business.count} negocios en total. Entra a / para verlos."
  end

  desc "Corre un sync AHORA (síncrono), útil para el primer sync real de auditoría"
  task :sync_now, [ :comuna, :rubro ] => :environment do |_t, args|
    comuna = find_comuna!(args[:comuna])
    rubro = Rubro.find_by!(key: args[:rubro])
    run = SyncJob.perform_now(comuna.id, rubro.id)
    puts "→ #{run.status}: #{run.found_count} encontrados (#{run.new_count} nuevos, " \
         "#{run.updated_count} actualizados, #{run.error_count} errores), #{run.api_calls} llamadas."
  end
end
