import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["manualForm", "redmineForm"]

  toggle(event) {
    const mode = event.target.id
    if (mode === "btn-manual") {
      this.manualFormTarget.style.display = "flex"
      this.redmineFormTarget.style.display = "none"
    } else if (mode === "btn-redmine") {
      this.manualFormTarget.style.display = "none"
      this.redmineFormTarget.style.display = "flex"
    }
  }
}
