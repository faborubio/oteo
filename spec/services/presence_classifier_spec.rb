require "rails_helper"

RSpec.describe PresenceClassifier do
  def classify(uri) = described_class.call(uri)

  describe "sin_presencia" do
    it "clasifica URI vacío o nil" do
      expect(classify(nil)).to eq("sin_presencia")
      expect(classify("")).to eq("sin_presencia")
      expect(classify("   ")).to eq("sin_presencia")
    end
  end

  describe "solo_redes (redes ≠ web propia — ADR-003)" do
    it "detecta redes sociales" do
      expect(classify("https://facebook.com/minegocio")).to eq("solo_redes")
      expect(classify("https://instagram.com/minegocio")).to eq("solo_redes")
      expect(classify("https://linktr.ee/minegocio")).to eq("solo_redes")
      expect(classify("https://wa.me/56912345678")).to eq("solo_redes")
      expect(classify("https://tiktok.com/@minegocio")).to eq("solo_redes")
    end

    it "detecta subdominios de redes (m.facebook.com, chat.whatsapp.com)" do
      expect(classify("https://m.facebook.com/minegocio")).to eq("solo_redes")
      expect(classify("https://chat.whatsapp.com/xyz")).to eq("solo_redes")
    end

    it "detecta agregadores de delivery como solo_redes (excelente lead — ADR-003)" do
      expect(classify("https://pedidosya.cl/restaurantes/curico/mi-picada")).to eq("solo_redes")
      expect(classify("https://www.rappi.cl/restaurantes/123")).to eq("solo_redes")
    end
  end

  describe "web_propia" do
    it "clasifica dominios propios" do
      expect(classify("https://minegocio.cl")).to eq("web_propia")
      expect(classify("http://www.losrobles.cl/menu")).to eq("web_propia")
    end

    it "ignora el prefijo www" do
      expect(classify("https://www.minegocio.cl")).to eq("web_propia")
    end

    it "acepta URIs sin esquema" do
      expect(classify("minegocio.cl")).to eq("web_propia")
      expect(classify("instagram.com/minegocio")).to eq("solo_redes")
    end

    it "no entierra como sin_presencia una URI presente pero rara" do
      expect(classify("not a real uri")).to eq("web_propia")
    end
  end

  describe "#shortener?" do
    it "detecta acortadores (destino desconocido sin resolver — ADR-003)" do
      expect(described_class.new("https://bit.ly/abc").shortener?).to be(true)
      expect(described_class.new("https://cutt.ly/xyz").shortener?).to be(true)
    end

    it "es false para dominios normales" do
      expect(described_class.new("https://minegocio.cl").shortener?).to be(false)
    end
  end
end
