import { Controller } from "@hotwired/stimulus"

// Initializes a Bootstrap tooltip on the element (reads its title attribute).
export default class extends Controller {
  connect() {
    if (window.bootstrap && window.bootstrap.Tooltip) {
      this._tooltip = new window.bootstrap.Tooltip(this.element)
    }
  }

  disconnect() {
    if (this._tooltip) {
      this._tooltip.dispose()
      this._tooltip = null
    }
  }
}
