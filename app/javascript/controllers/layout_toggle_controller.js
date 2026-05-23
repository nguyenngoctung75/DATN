import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["section", "buttonLabel", "icon"]
  static values = {
    hiddenByDefault: Boolean
  }

  connect() {
    if (this.hiddenByDefaultValue) {
      this.hide()
    } else {
      this.show()
    }
  }

  toggle(event) {
    if (event) event.preventDefault()
    
    const isHidden = this.sectionTargets[0].classList.contains("d-none")
    
    if (isHidden) {
      this.show()
    } else {
      this.hide()
    }
  }

  hide() {
    this.sectionTargets.forEach(target => {
      target.classList.add("d-none")
    })
    this.updateUI(true)
  }

  show() {
    this.sectionTargets.forEach(target => {
      target.classList.remove("d-none")
    })
    this.updateUI(false)
  }

  updateUI(hidden) {
    if (this.hasButtonLabelTarget) {
      this.buttonLabelTarget.textContent = hidden ? "Show Details" : "Hide Details"
    }
    
    if (this.hasIconTarget) {
      if (hidden) {
        this.iconTarget.classList.remove("bi-eye-slash")
        this.iconTarget.classList.add("bi-eye")
      } else {
        this.iconTarget.classList.remove("bi-eye")
        this.iconTarget.classList.add("bi-eye-slash")
      }
    }
  }
}
