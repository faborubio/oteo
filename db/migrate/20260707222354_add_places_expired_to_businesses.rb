class AddPlacesExpiredToBusinesses < ActiveRecord::Migration[8.1]
  def change
    # true cuando el job de expiración nulificó los campos de Places por retención
    # ToS > 30 días (AUD-012). place_id y el dato propio se conservan.
    add_column :businesses, :places_expired, :boolean, null: false, default: false
  end
end
