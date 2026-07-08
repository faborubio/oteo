require "rails_helper"

RSpec.describe BusinessesHelper, type: :helper do
  describe "#safe_external_url" do
    it "acepta http y https" do
      expect(helper.safe_external_url("https://minegocio.cl")).to eq("https://minegocio.cl")
      expect(helper.safe_external_url("http://minegocio.cl")).to eq("http://minegocio.cl")
    end

    it "rechaza esquemas peligrosos (XSS vía href)" do
      expect(helper.safe_external_url("javascript:alert(1)")).to be_nil
      expect(helper.safe_external_url("data:text/html,<script>")).to be_nil
      expect(helper.safe_external_url(nil)).to be_nil
    end
  end

  describe "#presence_badge" do
    it "renderiza la etiqueta legible del estado" do
      expect(helper.presence_badge("sin_presencia")).to include("Sin presencia")
    end
  end

  describe "#sales_script" do
    it "devuelve el guion del estado o nil" do
      expect(helper.sales_script("solo_redes")).to include("profesionalización")
      expect(helper.sales_script("web_propia")).to include("no es lead de web")
      expect(helper.sales_script(nil)).to be_nil
    end
  end

  describe "#contact_template" do
    it "interpola el nombre del negocio en la plantilla del estado" do
      business = build(:business, name: "Picada Doña Marta", digital_presence: "sin_presencia")
      expect(helper.contact_template(business)).to include("Picada Doña Marta").and include("página web")
    end

    it "cae a la plantilla de sin_presencia si no hay clasificación" do
      business = build(:business, name: "X", digital_presence: nil)
      expect(helper.contact_template(business)).to be_present
    end
  end

  describe "#whatsapp_link" do
    it "arma un link wa.me con solo dígitos y el mensaje pre-cargado" do
      business = build(:business, name: "Bar Central", phone: "+56 75 231 4455", digital_presence: "solo_redes")
      link = helper.whatsapp_link(business)
      expect(link).to start_with("https://wa.me/56752314455?text=")
      expect(link).to include(CGI.escape("Bar Central"))
    end

    it "antepone el código país 56 si el teléfono viene en formato nacional" do
      business = build(:business, name: "X", phone: "75 231 4455", digital_presence: "sin_presencia")
      expect(helper.whatsapp_link(business)).to start_with("https://wa.me/56752314455?text=")
    end

    it "es nil si no hay teléfono utilizable" do
      expect(helper.whatsapp_link(build(:business, phone: nil))).to be_nil
    end
  end
end
