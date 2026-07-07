class CreateSyncRuns < ActiveRecord::Migration[8.1]
  def change
    create_table :sync_runs do |t|
      t.references :comuna, null: false, foreign_key: true
      t.references :rubro, null: false, foreign_key: true
      # Texto real enviado a Places, incluida sub-consulta por sector/sinónimo (ADR-011).
      t.string :query
      t.string :status, null: false, default: "pending"
      t.datetime :started_at
      t.datetime :finished_at
      t.integer :found_count, null: false, default: 0
      t.integer :new_count, null: false, default: 0
      t.integer :updated_count, null: false, default: 0
      t.integer :error_count, null: false, default: 0
      # Contador de llamadas por SKU: obligatorio, no decorativo (ADR-002).
      t.integer :api_calls, null: false, default: 0
      t.text :notes

      t.timestamps
    end

    add_index :sync_runs, :created_at
  end
end
