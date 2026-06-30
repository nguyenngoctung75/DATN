import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.storageKey = `col-widths-${window.location.pathname}`
    this.resizing = false
    this.startX = 0
    this.startWidth = 0
    this.currentTh = null

    this.restoreWidths()
    this.addResizeHandles()

    this.onMouseMove = this.onMouseMove.bind(this)
    this.onMouseUp = this.onMouseUp.bind(this)
  }

  addResizeHandles() {
    const headers = this.element.querySelectorAll("thead th")
    headers.forEach((th, index) => {
      if (index === headers.length - 1) return

      const handle = document.createElement("div")
      handle.className = "col-resize-handle"
      handle.addEventListener("mousedown", (e) => this.onMouseDown(e, th))
      th.style.position = "relative"
      th.appendChild(handle)
    })
  }

  onMouseDown(event, th) {
    event.preventDefault()
    event.stopPropagation()
    this.resizing = true
    this.startX = event.clientX
    this.startWidth = th.offsetWidth
    this.currentTh = th

    document.addEventListener("mousemove", this.onMouseMove)
    document.addEventListener("mouseup", this.onMouseUp)
    document.body.style.cursor = "col-resize"
    document.body.style.userSelect = "none"
  }

  onMouseMove(event) {
    if (!this.resizing || !this.currentTh) return
    const diff = event.clientX - this.startX
    const newWidth = Math.max(50, this.startWidth + diff)
    this.currentTh.style.width = `${newWidth}px`
    this.currentTh.style.minWidth = `${newWidth}px`
  }

  disconnect() {
    if (this.resizing) {
      document.removeEventListener("mousemove", this.onMouseMove)
      document.removeEventListener("mouseup", this.onMouseUp)
      document.body.style.cursor = ""
      document.body.style.userSelect = ""
    }
  }

  onMouseUp() {
    if (!this.resizing) return
    this.resizing = false
    document.removeEventListener("mousemove", this.onMouseMove)
    document.removeEventListener("mouseup", this.onMouseUp)
    document.body.style.cursor = ""
    document.body.style.userSelect = ""
    this.saveWidths()
  }

  saveWidths() {
    const headers = this.element.querySelectorAll("thead th")
    const widths = Array.from(headers).map(th => th.offsetWidth)
    try {
      localStorage.setItem(this.storageKey, JSON.stringify(widths))
    } catch (e) {
    }
  }

  restoreWidths() {
    try {
      const saved = localStorage.getItem(this.storageKey)
      if (!saved) return
      const widths = JSON.parse(saved)
      const headers = this.element.querySelectorAll("thead th")
      headers.forEach((th, index) => {
        if (widths[index]) {
          th.style.width = `${widths[index]}px`
          th.style.minWidth = `${widths[index]}px`
        }
      })
    } catch (e) {
    }
  }
}
