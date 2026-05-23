import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="navigation"
export default class extends Controller {
  static values = {
    url: String
  }

  navigate(event) {
    // Allow middle-click to open in new tab
    if (event.ctrlKey || event.metaKey || event.button === 1) {
      window.open(this.urlValue, '_blank')
      return
    }

    window.location.href = this.urlValue
  }

  click(event) {
    this.navigate(event)
  }
}


