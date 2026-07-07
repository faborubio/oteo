class CreateRubros < ActiveRecord::Migration[8.1]
  def change
    create_table :rubros do |t|
      t.string :key, null: false
      t.string :label, null: false
      t.string :text_search_query, null: false
      t.boolean :pos_target, null: false, default: false
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :rubros, :key, unique: true
  end
end
