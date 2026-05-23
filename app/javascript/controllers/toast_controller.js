import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="toast"
export default class extends Controller {
  connect() {
    this._retryTimer = null
    this._toast = null
    this._onHidden = () => this.element.remove()
    this.initializeToast()
  }

  disconnect() {
    clearTimeout(this._retryTimer)
    this.element.removeEventListener('hidden.bs.toast', this._onHidden)
    this._toast?.dispose()
  }

  initializeToast() {
    if (typeof bootstrap !== 'undefined' && bootstrap.Toast) {
      this._toast = new bootstrap.Toast(this.element, { autohide: true, delay: 5000 })
      this.element.addEventListener('hidden.bs.toast', this._onHidden)
      this._toast.show()
    } else {
      this._retryTimer = setTimeout(() => this.initializeToast(), 100)
    }
  }
}

