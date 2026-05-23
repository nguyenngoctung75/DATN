import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    setTimeout(() => {
      this.dismiss()
    }, 3000)
  }

  dismiss() {
    this.element.classList.remove("show")

    setTimeout(() => {
      this.element.remove()
    }, 150)
  }
}
