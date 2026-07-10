class EnableUnaccentExtension < ActiveRecord::Migration[8.1]
  # Búsqueda por nombre insensible a tildes ("panaderia" encuentra "Panadería").
  # unaccent viene en postgresql-contrib (incluido en la imagen oficial postgres:16).
  def change
    enable_extension "unaccent"
  end
end
