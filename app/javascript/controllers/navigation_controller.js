import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    url: String
  }

  navigate(event) {
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
