class CreateBusinessRubros < ActiveRecord::Migration[8.1]
  def change
    create_table :business_rubros do |t|
      t.references :business, null: false, foreign_key: true
      t.references :rubro, null: false, foreign_key: true

      t.timestamps
    end

    # n:m negocio↔rubro (ADR-013): cada sync AGREGA el rubro por el que lo encontró,
    # nunca reemplaza; el par es único para no duplicar en cada corrida.
    add_index :business_rubros, [ :business_id, :rubro_id ], unique: true
  end
end
