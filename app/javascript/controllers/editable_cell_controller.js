import { Controller } from "@hotwired/stimulus"
import { csrfFetch } from "helpers/fetch_helper"
import { buildSaveRequest, sanitizePastedHtml } from "helpers/cell_save_helper"
import { toastError } from "helpers/toast_helper"
import { findHorizontalNeighbor, findVerticalNeighbor } from "helpers/cell_navigation_helper"

export default class extends Controller {
  static targets = ["display"]

  connect() {
    this.boundHandleKeydown = this.handleKeydown.bind(this)
    this.boundActivateDisplay = this.activateDisplay.bind(this)
    this.boundHandleLinkClick = this.handleLinkClick.bind(this)

    this.element.addEventListener("keydown", this.boundHandleKeydown)
    this.element.addEventListener("click", this.boundHandleLinkClick, true)
    this.displayTargets.forEach((display) => {
      display.tabIndex = 0
      display.classList.add("spreadsheet-cell-display")
      display.addEventListener("focus", this.boundActivateDisplay)
      display.addEventListener("click", this.boundActivateDisplay)
    })
  }

  disconnect() {
    this.element.removeEventListener("keydown", this.boundHandleKeydown)
    this.element.removeEventListener("click", this.boundHandleLinkClick, true)
    this.displayTargets.forEach((display) => {
      display.removeEventListener("focus", this.boundActivateDisplay)
      display.removeEventListener("click", this.boundActivateDisplay)
    })
  }

  activateDisplay(event) {
    this.setActiveDisplay(event.currentTarget)
  }

  handleLinkClick(event) {
    if (this.editing) return
    const anchor = event.target.closest("a[href]")
    if (!anchor) return
    event.preventDefault()
    event.stopPropagation()
    window.open(anchor.href, "_blank", "noopener,noreferrer")
  }

  edit(event) {
    if (this.editing) return
    this.editing = true
    
    const target = event.currentTarget
    const field = target.dataset.field
    const contentId = target.dataset.contentId
    const originalContent = target.innerHTML.trim()
    this.setActiveDisplay(target)
    
    // Make the target itself editable to prevent double-boxing or layout jumps
    target.contentEditable = "true"
    target.style.outline = "none" // Ensure browser doesn't add its own outline
    target.dataset.editableCellActive = "true"
    target.focus()
    
    // Place cursor at the end
    const range = document.createRange()
    range.selectNodeContents(target)
    range.collapse(false) // false means to the end of the range
    const sel = window.getSelection()
    sel.removeAllRanges()
    sel.addRange(range)

    const save = () => {
      const newContent = target.innerHTML.trim()
      if (newContent !== originalContent) {
        this.saveChange(field, contentId, newContent, target, originalContent)
      }
      this.finishEdit(target)
    }

    this.onBlur = (blurEvent) => {
      // If focus moved to a toolbar element (e.g. the font-size input), keep editing.
      // event.preventDefault() on mousedown already handles buttons; this covers inputs.
      if (blurEvent.relatedTarget?.closest?.('.spreadsheet-toolbar-sticky')) return
      document.dispatchEvent(new CustomEvent("spreadsheet-cell:blur", { detail: { element: target, display: target } }))
      save()
    }

    this.onPaste = (e) => {
      e.preventDefault()
      const cleaned = sanitizePastedHtml(e.clipboardData)
      if (cleaned) document.execCommand("insertHTML", false, cleaned)
    }

    this.onKeydown = (e) => {
      if (e.key === "Enter" && !e.shiftKey) {
        e.preventDefault()
        target.blur()
        setTimeout(() => this.navigateVertical(target, 1), 50)
      }
      if (e.key === "Tab") {
        e.preventDefault()
        target.blur()
        if (e.shiftKey) {
          setTimeout(() => this.navigateHorizontal(target, -1), 50)
        } else {
          setTimeout(() => this.navigateHorizontal(target, 1), 50)
        }
      }
      if (e.key === "Escape") {
        target.innerHTML = originalContent // Revert
        target.blur() // Save fires but detects no change
      }
    }

    target.addEventListener("blur", this.onBlur)
    target.addEventListener("paste", this.onPaste)
    target.addEventListener("keydown", this.onKeydown)

    // Manually trigger focus dispatch
    document.dispatchEvent(new CustomEvent("spreadsheet-cell:focus", { detail: { element: target, display: target } }))
  }

  finishEdit(target) {
    target.contentEditable = "false"
    target.style.outline = ""
    delete target.dataset.editableCellActive
    
    target.removeEventListener("blur", this.onBlur)
    target.removeEventListener("paste", this.onPaste)
    target.removeEventListener("keydown", this.onKeydown)
    
    this.editing = false
    this.setActiveDisplay(target)
  }

  setActiveDisplay(display) {
    document.querySelectorAll(".spreadsheet-cell-active").forEach((node) => {
      if (node !== display) node.classList.remove("spreadsheet-cell-active")
    })

    display.classList.add("spreadsheet-cell-active")
  }

  navigateHorizontal(currentDisplay, direction) {
    const next = findHorizontalNeighbor(currentDisplay, direction)
    if (next) next.click()
  }

  navigateVertical(currentDisplay, direction) {
    const next = findVerticalNeighbor(currentDisplay, direction)
    if (next) next.click()
  }

  handleKeydown(event) {
    if (this.editing) return

    const focused = document.activeElement
    if (!focused || !this.element.contains(focused)) return

    if (event.key === "Enter" && focused.matches("[data-editable-cell-target='display']")) {
      event.preventDefault()
      focused.click()
      return
    }

    if (!["ArrowUp", "ArrowDown", "ArrowLeft", "ArrowRight"].includes(event.key)) return

    event.preventDefault()
    const direction = event.key === "ArrowDown" || event.key === "ArrowRight" ? 1 : -1
    const isVertical = event.key === "ArrowUp" || event.key === "ArrowDown"
    const display = focused.closest("[data-editable-cell-target='display']")
    if (!display) return

    if (isVertical) {
      this.navigateVertical(display, direction)
    } else {
      this.navigateHorizontal(display, direction)
    }
  }

  saveChange(field, contentId, value, display, oldValue) {
    const { url, params } = buildSaveRequest(this.element, field, contentId, value)

    display.classList.remove("cell-error", "cell-saved")
    display.classList.add("cell-saving")

    csrfFetch(url, {
      method: "PATCH",
      body: JSON.stringify(params)
    })
    .then(response => response.json())
    .then(data => {
      display.classList.remove("cell-saving")

      if (data.id) {
        const toolbar = document.querySelector('.spreadsheet-toolbar')
        const isToolbarActive = toolbar && toolbar.contains(document.activeElement)
        const isSelfActive = document.activeElement === display
        
        if (!isSelfActive && !isToolbarActive && !display.dataset.formatting) {
          display.innerHTML = data.formatted_value || value
        }
        
        display.classList.add("cell-saved")
        setTimeout(() => display.classList.remove("cell-saved"), 1000)

        document.dispatchEvent(new CustomEvent("cell:changed", {
          detail: {
            url,
            params,
            oldValue,
            newValue: value,
            display,
            method: "PATCH"
          }
        }))

        document.dispatchEvent(new CustomEvent("cell:save-success", {
          detail: { url, params, value, display, data }
        }))
      }
    })
    .catch(error => {
      toastError("Failed to save changes.")
      display.classList.remove("cell-saving")
      display.classList.add("cell-error")
      setTimeout(() => display.classList.remove("cell-error"), 2000)

      document.dispatchEvent(new CustomEvent("cell:save-error", {
        detail: { url, params, value, display, error }
      }))
    })
  }
}
