module ApplicationHelper
  def nav_link_class(active)
    base = "text-sm font-medium "
    base + (active ? "text-emerald-700" : "text-gray-600 hover:text-gray-900")
  end

  # Key de Google Maps JS (browser, restringida por HTTP referrer — distinta de la de Places).
  def google_maps_api_key
    ENV["GOOGLE_MAPS_JS_API_KEY"].presence || Rails.application.credentials.dig(:google, :maps_js_api_key)
  end
end
