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
end
