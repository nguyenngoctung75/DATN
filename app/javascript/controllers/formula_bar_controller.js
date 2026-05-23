import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["ref", "input"]

  connect() {
    this._onFocus = (e) => this._cellFocused(e.detail.element)
    this._onBlur  = (e) => this._cellBlurred(e.detail.element)

    document.addEventListener("spreadsheet-cell:focus", this._onFocus)
    document.addEventListener("spreadsheet-cell:blur",  this._onBlur)

    this._onInputBlur = (e) => {
      if (!this.activeCell) return
      if (e.relatedTarget?.closest?.(".spreadsheet-toolbar-sticky")) return
      if (e.relatedTarget === this.activeCell) return
      const cell = this.activeCell
      cell.focus()
      cell.blur()
    }
    this.inputTarget.addEventListener("blur", this._onInputBlur)
  }

  disconnect() {
    document.removeEventListener("spreadsheet-cell:focus", this._onFocus)
    document.removeEventListener("spreadsheet-cell:blur",  this._onBlur)
    this.inputTarget.removeEventListener("blur", this._onInputBlur)
    this._clearCellListener()
  }

  _cellFocused(cell) {
    this._clearCellListener()
    this.activeCell = cell

    const row = cell.closest("tr")
    const idSpan = row?.querySelector("td:first-child span")
    this.refTarget.textContent = idSpan?.textContent.trim() || ""

    this.inputTarget.innerHTML = cell.innerHTML
    this.inputTarget.contentEditable = "true"

    this._onCellInput = () => {
      this.inputTarget.innerHTML = this.activeCell.innerHTML
    }
    cell.addEventListener("input", this._onCellInput)
  }

  _cellBlurred(cell) {
    if (this.activeCell !== cell) return
    this._clearCellListener()
    this.activeCell = null
    this.refTarget.textContent = ""
    this.inputTarget.innerHTML = ""
    this.inputTarget.contentEditable = "false"
  }

  _clearCellListener() {
    if (this._onCellInput && this.activeCell) {
      this.activeCell.removeEventListener("input", this._onCellInput)
      this._onCellInput = null
    }
  }

  syncToCell() {
    if (!this.activeCell) return
    this.activeCell.innerHTML = this.inputTarget.innerHTML
  }
}
