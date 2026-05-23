import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal", "modalImage", "modalVideo", "modalVideoSource", "modalLink"]

  connect() {
    this.modal = new window.bootstrap.Modal(document.getElementById('mediaPreviewModal'))
    this.modalElement = document.getElementById('mediaPreviewModal')
  }

  open(event) {
    event.preventDefault()
    const url = event.currentTarget.dataset.url
    const type = event.currentTarget.dataset.type

    // Hide all content first
    this.modalImageTarget.classList.add('d-none')
    this.modalVideoTarget.classList.add('d-none')
    this.modalLinkTarget.classList.add('d-none')

    if (type === 'image') {
      this.modalImageTarget.src = url
      this.modalImageTarget.classList.remove('d-none')
    } else if (type === 'video') {
      this.modalVideoSourceTarget.src = url
      this.modalVideoTarget.load()
      this.modalVideoTarget.classList.remove('d-none')
    } else {
      let iframe = this.modalLinkTarget.querySelector('iframe')
      if (!iframe) {
        iframe = document.createElement('iframe')
        iframe.style.width = '100%'
        iframe.style.height = '85vh'
        iframe.style.border = 'none'
        this.modalLinkTarget.appendChild(iframe)
      }
      iframe.src = url
      this.modalLinkTarget.classList.remove('d-none')
    }

    this.modal.show()
  }
}
