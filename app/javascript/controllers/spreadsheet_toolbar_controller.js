import { Controller } from "@hotwired/stimulus"
import { toastError } from "helpers/toast_helper"

const FONT_SIZE_STEP = 1
const DEFAULT_FONT_SIZE = 13
const MIN_FONT_SIZE = 6
const MAX_FONT_SIZE = 96

const H_ALIGN_CMDS  = { left: "justifyLeft",   center: "justifyCenter",  right: "justifyRight" }
const H_ALIGN_ICONS = { left: "bi-text-left",  center: "bi-text-center", right: "bi-text-right" }
const V_ALIGN_ICONS = { top: "bi-align-top",   middle: "bi-align-middle", bottom: "bi-align-bottom" }

export default class extends Controller {
  static targets = [
    "fontNameBtn", "fontSizeInput",
    "textColorBar", "fillColorBar",
    "hAlignBtn", "vAlignBtn",
    "linkWrapper", "linkPopover", "linkInput"
  ]

  connect() {
    this.activeCell = null
    this.savedSelection = null

    this._onFocus = (e) => { this.activeCell = e.detail.element; this.saveSelection() }
    this._onBlur  = (e) => { if (this.activeCell === e.detail.element) this.saveSelection() }
    this._onSelChange = () => {
      if (this.activeCell && document.activeElement === this.activeCell) this.saveSelection()
    }

    document.addEventListener("spreadsheet-cell:focus", this._onFocus)
    document.addEventListener("spreadsheet-cell:blur",  this._onBlur)
    document.addEventListener("selectionchange", this._onSelChange)

    if (this.hasFontSizeInputTarget) {
      this._onSizeInputFocus = () => this.saveSelection()
      this.fontSizeInputTarget.addEventListener("focus", this._onSizeInputFocus)
    }
  }

  disconnect() {
    document.removeEventListener("spreadsheet-cell:focus", this._onFocus)
    document.removeEventListener("spreadsheet-cell:blur",  this._onBlur)
    document.removeEventListener("selectionchange", this._onSelChange)
    if (this.hasFontSizeInputTarget && this._onSizeInputFocus) {
      this.fontSizeInputTarget.removeEventListener("focus", this._onSizeInputFocus)
    }
  }

  saveSelection() {
    const sel = window.getSelection()
    if (sel.rangeCount > 0) {
      const range = sel.getRangeAt(0)
      if (this.activeCell && this.activeCell.contains(range.commonAncestorContainer)) {
        this.savedSelection = range.cloneRange()
      }
    }
  }

  restoreSelection() {
    if (!this.savedSelection || !this.activeCell) return
    this.activeCell.focus()
    const sel = window.getSelection()
    sel.removeAllRanges()
    try { sel.addRange(this.savedSelection) } catch (_) {}
  }

  _ensureEditableWithSelection() {
    if (!this.activeCell || this.activeCell.contentEditable !== "true") return false
    this.activeCell.focus()
    if (this.savedSelection && !this.savedSelection.collapsed) {
      const sel = window.getSelection()
      sel.removeAllRanges()
      try { sel.addRange(this.savedSelection) } catch (_) {}
    } else {
      const range = document.createRange()
      range.selectNodeContents(this.activeCell)
      const sel = window.getSelection()
      sel.removeAllRanges()
      sel.addRange(range)
    }
    return true
  }

  preventFocusLoss(event) {
    if (["INPUT", "TEXTAREA"].includes(event.target.tagName) || event.target.closest('[contenteditable="true"]')) {
      this.saveSelection()
      return
    }
    event.preventDefault()
    if (this.activeCell) this.restoreSelection()
  }

  _exec(command, value = null) {
    if (!this._ensureEditableWithSelection()) return false
    this.activeCell.dataset.formatting = "true"
    document.execCommand(command, false, value)
    setTimeout(() => {
      this.saveSelection()
      if (this.activeCell) delete this.activeCell.dataset.formatting
    }, 50)
    return true
  }

  format(event) {
    event.preventDefault()
    this._exec(event.currentTarget.dataset.command, event.currentTarget.dataset.value || null)
  }

  undo(event) {
    event.preventDefault()
    this.application.getControllerForElementAndIdentifier(this.element, "undo-redo")?.undo()
  }

  redo(event) {
    event.preventDefault()
    this.application.getControllerForElementAndIdentifier(this.element, "undo-redo")?.redo()
  }

  fontName(event) {
    event.preventDefault()
    const font = event.currentTarget.dataset.font
    if (!font) return
    this._exec("fontName", font)
    if (this.hasFontNameBtnTarget) this.fontNameBtnTarget.textContent = font
  }

  fontSizeMinus(event) {
    event.preventDefault()
    this._adjustFontSize(-FONT_SIZE_STEP)
  }

  fontSizePlus(event) {
    event.preventDefault()
    this._adjustFontSize(FONT_SIZE_STEP)
  }

  fontSizeFromInput(event) {
    const px = parseInt(event.currentTarget.value, 10)
    if (!isNaN(px) && px >= MIN_FONT_SIZE && px <= MAX_FONT_SIZE) this._applyFontSize(px)
  }

  _adjustFontSize(delta) {
    const current = this.hasFontSizeInputTarget
      ? (parseInt(this.fontSizeInputTarget.value, 10) || DEFAULT_FONT_SIZE)
      : DEFAULT_FONT_SIZE
    const next = Math.min(MAX_FONT_SIZE, Math.max(MIN_FONT_SIZE, current + delta))
    if (this.hasFontSizeInputTarget) this.fontSizeInputTarget.value = next
    this._applyFontSize(next)
  }

  _applyFontSize(px) {
    if (!this._ensureEditableWithSelection()) return
    this.activeCell.dataset.formatting = "true"
    document.execCommand("fontSize", false, "7")
    this.activeCell.querySelectorAll("font[size='7']").forEach(el => {
      const span = document.createElement("span")
      span.style.fontSize = `${px}px`
      span.innerHTML = el.innerHTML
      el.replaceWith(span)
    })
    setTimeout(() => {
      this.saveSelection()
      if (this.activeCell) delete this.activeCell.dataset.formatting
    }, 50)
  }

  applyTextColor(event) {
    event.preventDefault()
    const color = event.currentTarget.dataset.color
    if (!color) return
    if (this.hasTextColorBarTarget) this.textColorBarTarget.style.background = color
    this._exec("foreColor", color)
  }

  applyFillColor(event) {
    event.preventDefault()
    const color = event.currentTarget.dataset.color
    if (!color) return
    const bg = color === "transparent" ? "#ffffff" : color
    if (this.hasFillColorBarTarget) this.fillColorBarTarget.style.background = bg
    this._exec("hiliteColor", bg)
  }

  mergeRows(event) {
    event.preventDefault()
    const ctrl = this._getFgCtrl()
    if (ctrl) ctrl.mergeExternal()
    else toastError("Select a cell in a mergeable row first.")
  }

  unmergeRows(event) {
    event.preventDefault()
    const ctrl = this._getFgCtrl()
    if (ctrl) ctrl.splitExternal()
    else toastError("Select a cell in a group to unmerge.")
  }

  _getFgCtrl() {
    if (!this.activeCell) return null
    const row = this.activeCell.closest("tr")
    const fgEl = row?.querySelector('[data-controller~="function-group"]')
    if (!fgEl) return null
    return this.application.getControllerForElementAndIdentifier(fgEl, "function-group")
  }

  alignHorizontal(event) {
    event.preventDefault()
    const align = event.currentTarget.dataset.align
    if (!H_ALIGN_CMDS[align]) return
    this._exec(H_ALIGN_CMDS[align])
    if (this.hasHAlignBtnTarget) {
      const icon = this.hAlignBtnTarget.querySelector("i")
      if (icon) icon.className = `bi ${H_ALIGN_ICONS[align]}`
    }
  }

  alignVertical(event) {
    event.preventDefault()
    const align = event.currentTarget.dataset.align
    const td = this.activeCell?.closest("td")
    if (!td || !align) return
    td.style.verticalAlign = align
    if (this.hasVAlignBtnTarget && V_ALIGN_ICONS[align]) {
      const icon = this.vAlignBtnTarget.querySelector("i")
      if (icon) icon.className = `bi ${V_ALIGN_ICONS[align]}`
    }
  }

  toggleLinkPopover(event) {
    event.preventDefault()
    this.saveSelection()
    if (!this.hasLinkPopoverTarget) return
    const hidden = this.linkPopoverTarget.classList.toggle("d-none")
    if (!hidden && this.hasLinkInputTarget) {
      const sel = window.getSelection()
      const node = sel?.anchorNode
      const existingAnchor = (node?.nodeType === Node.TEXT_NODE ? node.parentElement : node)?.closest?.("a")
      if (existingAnchor) {
        const range = document.createRange()
        range.selectNodeContents(existingAnchor)
        sel.removeAllRanges()
        sel.addRange(range)
        this.savedSelection = range.cloneRange()
        this.linkInputTarget.value = existingAnchor.getAttribute("href") || ""
      } else {
        this.linkInputTarget.value = ""
      }
      setTimeout(() => this.linkInputTarget.focus(), 30)
    }
  }

  linkKeydown(event) {
    if (event.key === "Enter")  { event.preventDefault(); this._doInsertLink() }
    if (event.key === "Escape") { this.linkPopoverTarget.classList.add("d-none"); this.restoreSelection() }
  }

  applyLink(event) {
    event.preventDefault()
    this._doInsertLink()
  }

  _doInsertLink() {
    const url = this.hasLinkInputTarget ? this.linkInputTarget.value.trim() : ""
    if (this.hasLinkPopoverTarget) this.linkPopoverTarget.classList.add("d-none")
    if (!url) return
    if (!this.savedSelection || this.savedSelection.collapsed) {
      toastError("Select some text first to insert a link.")
      return
    }
    this._exec("createLink", url)
  }

  formatLink(event) { this.toggleLinkPopover(event) }
}
