import { Controller } from "@hotwired/stimulus"

// Mapa de leads con Google Maps JS (ADR-007 / AUD-002). Carga la librería bajo demanda
// (no via importmap: Google la adjunta a window), plotea marcadores coloreados por
// digital_presence y abre una ficha al hacer click. Los colores coinciden con
// BusinessesHelper::PRESENCE_MARKER_COLOR.
export default class extends Controller {
  static targets = ["canvas"]
  static values = { apiKey: String, markers: Array }

  COLORS = {
    sin_presencia: "#dc2626",
    solo_redes: "#ea580c",
    web_propia: "#9ca3af",
    web_caida: "#ca8a04",
  }

  async connect() {
    try {
      await this.loadGoogleMaps()
      this.render()
    } catch (e) {
      this.canvasTarget.innerHTML =
        '<div class="p-6 text-sm text-red-700">No se pudo cargar Google Maps. Revisa la API key y sus restricciones.</div>'
    }
  }

  loadGoogleMaps() {
    if (window.google?.maps) return Promise.resolve()
    if (window.__oteoMapsPromise) return window.__oteoMapsPromise

    window.__oteoMapsPromise = new Promise((resolve, reject) => {
      const cb = "__oteoMapsInit"
      window[cb] = () => resolve()
      const script = document.createElement("script")
      script.src = `https://maps.googleapis.com/maps/api/js?key=${this.apiKeyValue}&callback=${cb}&loading=async`
      script.async = true
      script.onerror = reject
      document.head.appendChild(script)
    })
    return window.__oteoMapsPromise
  }

  render() {
    const center = { lat: -35.42, lng: -71.65 } // Región del Maule
    const map = new google.maps.Map(this.canvasTarget, {
      center,
      zoom: 12,
      mapTypeControl: false,
      streetViewControl: false,
    })
    const bounds = new google.maps.LatLngBounds()
    const info = new google.maps.InfoWindow()

    this.markersValue.forEach((m) => {
      const marker = new google.maps.Marker({
        position: { lat: m.lat, lng: m.lng },
        map,
        title: m.name,
        icon: this.icon(m.presence),
      })
      bounds.extend(marker.getPosition())
      marker.addListener("click", () => {
        info.setContent(this.popup(m))
        info.open(map, marker)
      })
    })

    if (this.markersValue.length) map.fitBounds(bounds)
  }

  icon(presence) {
    return {
      path: google.maps.SymbolPath.CIRCLE,
      fillColor: this.COLORS[presence] || "#6b7280",
      fillOpacity: 1,
      strokeColor: "#ffffff",
      strokeWeight: 1.5,
      scale: 7,
    }
  }

  popup(m) {
    const name = this.escape(m.name)
    return `<div style="font-size:13px;line-height:1.4">
      <strong>${name}</strong><br>
      ${this.escape(m.comuna)} · score ${m.score.toFixed(1)}<br>
      <a href="${m.url}" style="color:#047857">Ver ficha →</a>
    </div>`
  }

  escape(text) {
    const div = document.createElement("div")
    div.textContent = text
    return div.innerHTML
  }
}
