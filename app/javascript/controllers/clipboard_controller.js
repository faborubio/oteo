import { Controller } from "@hotwired/stimulus"

// Copia el texto de un target al portapapeles y da feedback breve en el botón.
export default class extends Controller {
  static targets = ["source", "button"]

  async copy() {
    try {
      await navigator.clipboard.writeText(this.sourceTarget.value ?? this.sourceTarget.textContent)
      this.flash("¡Copiado!")
    } catch {
      this.flash("No se pudo copiar")
    }
  }

  flash(message) {
    if (!this.hasButtonTarget) return
    const original = this.buttonTarget.textContent
    this.buttonTarget.textContent = message
    setTimeout(() => (this.buttonTarget.textContent = original), 1500)
  }
}
