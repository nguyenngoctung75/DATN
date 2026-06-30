import { Controller } from "@hotwired/stimulus"
import { csrfFetch } from 'helpers/fetch_helper'

export default class extends Controller {
  connect() {
    this.undoStack = []
    this.redoStack = []
    this.maxHistory = 50

    this.boundPushChange = this.pushChange.bind(this)
    this.boundHandleKeydown = this.handleKeydown.bind(this)

    document.addEventListener("cell:changed", this.boundPushChange)
    document.addEventListener("keydown", this.boundHandleKeydown)
  }

  disconnect() {
    document.removeEventListener("cell:changed", this.boundPushChange)
    document.removeEventListener("keydown", this.boundHandleKeydown)
  }

  pushChange(event) {
    const { url, params, oldValue, newValue, display, method } = event.detail
    if (!url || oldValue === newValue) return

    this.undoStack.push({ url, params, oldValue, newValue, display, method: method || "PATCH" })
    if (this.undoStack.length > this.maxHistory) this.undoStack.shift()
    this.redoStack = []
  }

  handleKeydown(event) {
    const activeElement = document.activeElement
    if (activeElement && activeElement.contentEditable === "true") return

    if ((event.ctrlKey || event.metaKey) && event.key === "z" && !event.shiftKey) {
      event.preventDefault()
      this.undo()
    }
    if ((event.ctrlKey || event.metaKey) && event.key === "z" && event.shiftKey) {
      event.preventDefault()
      this.redo()
    }
    if ((event.ctrlKey || event.metaKey) && event.key === "y") {
      event.preventDefault()
      this.redo()
    }
  }

  undo() {
    const change = this.undoStack.pop()
    if (!change) return this.showToast("Nothing to undo")

    this.redoStack.push(change)
    this.applyChange(change.url, change.params, change.oldValue, change.display, "Undo")
  }

  redo() {
    const change = this.redoStack.pop()
    if (!change) return this.showToast("Nothing to redo")

    this.undoStack.push(change)
    this.applyChange(change.url, change.params, change.newValue, change.display, "Redo")
  }

  applyChange(url, originalParams, value, display, action) {
    const params = JSON.parse(JSON.stringify(originalParams))
    for (const key of Object.keys(params)) {
      if (typeof params[key] === "object") {
        for (const field of Object.keys(params[key])) {
          params[key][field] = value
        }
      }
    }

    csrfFetch(url, {
      method: "PATCH",
      body: JSON.stringify(params)
    })
    .then(r => r.json())
    .then(data => {
      if (display && data.id) {
        display.innerHTML = data.formatted_value || value
      }
      this.showToast(`${action} successful`)
    })
    .catch(() => {
      this.showToast(`${action} failed`)
    })
  }

  showToast(message) {
    const toast = document.createElement("div")
    toast.className = "spreadsheet-toast"
    toast.textContent = message
    document.body.appendChild(toast)
    setTimeout(() => toast.classList.add("show"), 10)
    setTimeout(() => {
      toast.classList.remove("show")
      setTimeout(() => toast.remove(), 300)
    }, 1500)
  }
}
