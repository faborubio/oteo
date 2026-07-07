class CreateContactEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :contact_events do |t|
      t.references :business, null: false, foreign_key: true
      t.string :event_type, null: false
      t.string :product
      t.text :body
      t.datetime :occurred_at, null: false

      t.timestamps
    end

    add_index :contact_events, [ :business_id, :occurred_at ]
  end
end
