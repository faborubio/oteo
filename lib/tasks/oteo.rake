namespace :oteo do
  desc "Encola un sync de una combinación: rake 'oteo:sync_one[curico,restaurantes]'"
  task :sync_one, [ :comuna, :rubro ] => :environment do |_t, args|
    comuna = Comuna.find_by!("lower(name) = ?", args[:comuna].to_s.downcase)
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

  desc "Corre un sync AHORA (síncrono), útil para el primer sync real de auditoría"
  task :sync_now, [ :comuna, :rubro ] => :environment do |_t, args|
    comuna = Comuna.find_by!("lower(name) = ?", args[:comuna].to_s.downcase)
    rubro = Rubro.find_by!(key: args[:rubro])
    run = SyncJob.perform_now(comuna.id, rubro.id)
    puts "→ #{run.status}: #{run.found_count} encontrados (#{run.new_count} nuevos, " \
         "#{run.updated_count} actualizados, #{run.error_count} errores), #{run.api_calls} llamadas."
  end
end
