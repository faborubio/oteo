class CreateBusinesses < ActiveRecord::Migration[8.1]
  def change
    create_table :businesses do |t|
      # Origen del registro (ADR-012): places sincroniza; manual es 100% dato propio.
      t.string :source, null: false, default: "places"
      # Clave estable de Places (ADR-006). Nullable porque los negocios manuales
      # no existen en Google; índice único parcial más abajo.
      t.string :place_id

      # --- Datos de Places (perecibles, refrescables por ventana ToS — ADR-006) ---
      t.string :name, null: false
      t.string :address
      t.decimal :lat, precision: 10, scale: 6
      t.decimal :lng, precision: 10, scale: 6
      t.string :phone
      t.decimal :rating, precision: 2, scale: 1
      t.integer :user_rating_count, null: false, default: 0
      t.string :website_uri
      t.jsonb :types, null: false, default: []
      t.string :business_status
      t.datetime :synced_at

      # --- Clasificación calculada (ADR-003/004/008) ---
      t.string :digital_presence
      t.boolean :pos_candidate, null: false, default: false
      t.decimal :lead_score, precision: 8, scale: 3, null: false, default: 0

      # --- Datos propios (permanentes, retención ilimitada — ADR-006) ---
      t.string :pos_status, null: false, default: "desconocido"
      t.string :pos_vendor
      t.string :pipeline_stage, null: false, default: "nuevo"

      # Comuna asignada desde la consulta de origen, no parseando la dirección (ADR-013).
      t.references :comuna, null: false, foreign_key: true

      t.timestamps
    end

    # place_id único solo cuando existe (ADR-012): permite muchos negocios manuales sin place_id.
    add_index :businesses, :place_id, unique: true, where: "place_id IS NOT NULL"

    # Índices sobre los filtros reales del dashboard (SAD §6).
    add_index :businesses, :digital_presence
    add_index :businesses, :lead_score
    add_index :businesses, :pipeline_stage
    add_index :businesses, :business_status
    add_index :businesses, :source
  end
end
