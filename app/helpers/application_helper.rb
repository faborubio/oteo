module ApplicationHelper
  def nav_link_class(active)
    base = "text-sm font-medium "
    base + (active ? "text-emerald-700" : "text-gray-600 hover:text-gray-900")
  end

  # Key de Google Maps JS (browser, restringida por HTTP referrer — distinta de la de Places).
  def google_maps_api_key
    ENV["GOOGLE_MAPS_JS_API_KEY"].presence || Rails.application.credentials.dig(:google, :maps_js_api_key)
  end

  # Paginación con la página actual notoria y números separados (uso en celular en terreno:
  # targets táctiles ≥36px). Construida sobre pagy.series para controlar el markup con Tailwind.
  def pagy_styled_nav(pagy)
    base = "inline-flex items-center justify-center min-w-9 h-9 px-2 rounded-md text-sm"
    link = "#{base} border border-gray-300 bg-white text-gray-700 hover:bg-gray-100"
    off  = "#{base} border border-gray-200 bg-gray-50 text-gray-300"

    items = []
    items << (pagy.previous ? link_to("‹", pagy.page_url(pagy.previous), class: link, aria: { label: "Anterior" }) : tag.span("‹", class: off))
    pagy.send(:series).each do |item|
      items << case item
      when Integer then link_to(item, pagy.page_url(item), class: link)
      when String  then tag.span(item, class: "#{base} bg-emerald-600 text-white font-semibold", aria: { current: "page" })
      else              tag.span("…", class: "#{base} text-gray-400")
      end
    end
    items << (pagy.next ? link_to("›", pagy.page_url(pagy.next), class: link, aria: { label: "Siguiente" }) : tag.span("›", class: off))

    tag.nav(safe_join(items), class: "flex flex-wrap items-center gap-1.5", aria: { label: "Páginas" })
  end
end
