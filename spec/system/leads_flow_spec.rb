require "rails_helper"

# Flujo de uso diario sin JS (driver rack_test): login → tabla → ficha → registrar contacto.
# El drag&drop del kanban y el mapa requieren JS y se verifican en CI / manualmente.
RSpec.describe "Flujo de prospección", type: :system do
  let(:user) { create(:user) }
  let(:comuna) { create(:comuna, name: "Curicó") }

  before { sign_in(user) }

  it "desde la tabla abre una ficha y registra un contacto" do
    business = create(:business, :sin_presencia, name: "Panadería San José",
                                 comuna: comuna, user_rating_count: 120)

    visit businesses_path
    expect(page).to have_content("Panadería San José")
    expect(page).to have_content("Con reputación")

    click_link "Panadería San José"

    expect(page).to have_content("Ángulo de venta")
    expect(page).to have_content("visibilidad") # guion de sin_presencia (ADR-003)
    expect(page).to have_content("POS")

    fill_in "contact_event[body]", with: "Llamé, interesado en una web."
    click_button "Registrar"

    expect(page).to have_content("Llamé, interesado en una web.")
    expect(business.contact_events.count).to eq(1)
  end

  it "el carril 'nuevos' separa los negocios sin reputación (ADR-008)" do
    create(:business, :sin_reputacion, name: "Kiosco Nuevo", comuna: comuna)
    create(:business, name: "Con Reseñas", comuna: comuna, user_rating_count: 80)

    visit businesses_path
    expect(page).to have_content("Con Reseñas")
    expect(page).not_to have_content("Kiosco Nuevo")

    click_link "Nuevos / sin reputación"
    expect(page).to have_content("Kiosco Nuevo")
    expect(page).not_to have_content("Con Reseñas")
  end
end
