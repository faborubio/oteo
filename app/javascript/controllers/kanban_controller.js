import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"

// Kanban CRM (ADR-009): drag & drop entre columnas. Cada movimiento persiste el nuevo
// pipeline_stage vía PATCH y el servidor deja un contact_event en el historial.
export default class extends Controller {
  static targets = ["column"]
  static values = { url: String }

  connect() {
    this.sortables = this.columnTargets.map((column) =>
      Sortable.create(column, {
        group: "pipeline",
        animation: 150,
        onEnd: (event) => this.persist(event),
      })
    )
  }

  disconnect() {
    this.sortables?.forEach((sortable) => sortable.destroy())
  }

  persist(event) {
    const id = event.item.dataset.id
    const stage = event.to.dataset.stage
    if (!id || !stage) return

    fetch(this.urlValue.replace("__ID__", id), {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": this.csrfToken,
        "Accept": "text/vnd.turbo-stream.html",
      },
      body: JSON.stringify({ stage }),
    }).then((response) => {
      if (!response.ok) window.location.reload() // revertir estado en caso de error
    })
  }

  get csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content
  }
}
