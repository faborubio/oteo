class CreateComunas < ActiveRecord::Migration[8.1]
  def change
    create_table :comunas do |t|
      t.string :name, null: false
      t.string :region, null: false, default: "Maule"
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :comunas, :name, unique: true
  end
end
