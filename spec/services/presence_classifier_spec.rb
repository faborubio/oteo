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

    it "detecta constructores de sitios como solo_redes (caso real Curicó — CASES.md)" do
      # trattoria-de-vali.ueniweb.com — página plantilla de UENI, no web propia.
      expect(classify("https://trattoria-de-vali.ueniweb.com/?utm_campaign=gmb")).to eq("solo_redes")
      expect(classify("https://mi-negocio.wixsite.com/inicio")).to eq("solo_redes")
      expect(classify("https://minegocio.business.site")).to eq("solo_redes")
      # cartas.horecaqr.com — plataforma de menús QR (caso real Curicó)
      expect(classify("https://cartas.horecaqr.com/c/trattorialapasta")).to eq("solo_redes")
      # plataformas detectadas en el populate del Maule (CASES.md 2026-07-08)
      expect(classify("https://menu.fu.do/mirestaurant")).to eq("solo_redes")
      expect(classify("https://mirestaurant.pedix.app")).to eq("solo_redes")
      expect(classify("https://wa.link/abc123")).to eq("solo_redes")
      expect(classify("https://fresha.com/a/mi-peluqueria")).to eq("solo_redes")
    end

    it "detecta la segunda capa de plataformas del Maule (CASES.md 2026-07-08)" do
      # AgendaPro: subdominios de reserva para peluquerías/barberías (9 negocios)
      expect(classify("https://basics.site.agendapro.com/cl")).to eq("solo_redes")
      expect(classify("https://barberiastatusspa.agendapro.com/cl")).to eq("solo_redes")
      expect(classify("https://link.agendapro.com/cl/monkeyboss/a5b55420")).to eq("solo_redes")
      # menú/pedidos/reserva de terceros
      expect(classify("https://toteat.app/r/cl/Susheria-Constitucion/3908/menu")).to eq("solo_redes")
      expect(classify("https://sushimax-chl.ola.click/")).to eq("solo_redes")
      expect(classify("https://oddmenu.com/es/p/takes")).to eq("solo_redes")
      expect(classify("https://www.restomovil.com/mkt/carta/114_landing.html")).to eq("solo_redes")
      expect(classify("https://kyte.site/panaderia-villota")).to eq("solo_redes")
      expect(classify("https://unicas.skedu.com/")).to eq("solo_redes")
      expect(classify("https://book.heygoldie.com/Guti-Barber10")).to eq("solo_redes")
      expect(classify("http://pedixwpp.com/alforno")).to eq("solo_redes")
      # subdominios gratuitos de constructor/host y contenido alojado
      expect(classify("https://condimento.webnode.es")).to eq("solo_redes")
      expect(classify("https://campingsueno.wordpress.com")).to eq("solo_redes")
      expect(classify("https://botilleriablackice.github.io")).to eq("solo_redes")
      expect(classify("https://drive.google.com/file/d/1_lgyS9/view")).to eq("solo_redes")
      # link-in-bio / WhatsApp / listado Google
      expect(classify("https://bio.site/laroccar")).to eq("solo_redes")
      expect(classify("https://bio.link/tu_farmacia_amiga")).to eq("solo_redes")
      expect(classify("https://linkinsta.com/piscolima.constitucion")).to eq("solo_redes")
      expect(classify("https://msha.ke/ameliapasteleria/")).to eq("solo_redes")
      expect(classify("https://w.app/emporiomadrid")).to eq("solo_redes")
      expect(classify("https://g.page/r/CYYdRD-5C8R4EAI/review")).to eq("solo_redes")
      # directorios y agregadores de viaje
      expect(classify("https://www.mercantil.com/empresa/farmacia-molina/molina/300323147/esp/")).to eq("solo_redes")
      expect(classify("https://www.booking.com/Share-r4Pu5fy")).to eq("solo_redes")
      expect(classify("https://www.tripadvisor.com.ar/Restaurant_Review-x.html")).to eq("solo_redes")
    end
  end

  describe "web_propia con dominio propio aunque use un constructor" do
    it "un .cl propio NO matchea el subdominio del constructor" do
      # Si usan Wix/UENI pero con su dominio comprado, eso SÍ es web propia.
      expect(classify("https://ueniweb.com.cl")).to eq("web_propia") # dominio distinto
      expect(classify("https://minegocio.cl")).to eq("web_propia")
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
