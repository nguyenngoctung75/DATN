import { Controller } from "@hotwired/stimulus"
import { readRow, saveCell, pasteRow, pasteCellContent } from 'helpers/clipboard_helper'
import { buildMenuHTML, positionMenu, getEditableCells, findEditableInCell, clickFormOrIcon, showSpreadsheetToast } from 'helpers/menu_renderer'

// Right-click context menu for spreadsheet cells & rows.
export default class extends Controller {
  connect() {
    this.menu = null
    this.activeRow = null
    this.activeCell = null
    this.copiedCellText = null
    this.copiedCellHTML = null
    this.copiedRowData = null

    this.boundShow = this.show.bind(this)
    this.boundHide = this.hide.bind(this)
    this.boundKeydown = (e) => { if (e.key === "Escape") this.hide() }

    this.element.addEventListener("contextmenu", this.boundShow)
    document.addEventListener("click", this.boundHide)
    document.addEventListener("keydown", this.boundKeydown)
  }

  disconnect() {
    this.hide()
    this.element.removeEventListener("contextmenu", this.boundShow)
    document.removeEventListener("click", this.boundHide)
    document.removeEventListener("keydown", this.boundKeydown)
  }

  show(event) {
    const row = event.target.closest("tr")
    if (!row || row.closest("thead")) return

    event.preventDefault()
    this.activeRow = row
    this.activeCell = event.target.closest("td")
    this.hide()

    const hasRowCopy  = this.resolveRowData() !== null
    const hasCellCopy = this.copiedCellText !== null || !!localStorage.getItem("spreadsheet_copied_cell_text")

    // Detect merge/split availability from DOM — merge button exists on all function rows,
    // split (scissors) only on group-head rows (rowspan > 1).
    const canMerge = !!row.querySelector('[data-action*="function-group#merge"]')
    const canSplit  = !!row.querySelector('[data-action*="function-group#split"]')

    // Archived rows render a restore button instead of an archive one; in that
    // view the destructive action permanently deletes the test case.
    const isArchived = !!row.querySelector(".bi-arrow-counterclockwise")

    this.menu = document.createElement("div")
    this.menu.className = "spreadsheet-context-menu"
    this.menu.innerHTML = buildMenuHTML(hasCellCopy, hasRowCopy, { canMerge, canSplit, isArchived })
    this.menu.style.position = "fixed"
    this.menu.style.zIndex = "9999"
    document.body.appendChild(this.menu)
    positionMenu(this.menu, event.clientX, event.clientY)

    const hasField = !!(this.activeCell?.dataset?.cellField)
    const histItem = this.menu.querySelector('[data-action-type="history"]')
    if (histItem && !hasField) histItem.classList.add("ctx-disabled")

    this.menu.querySelectorAll("[data-action-type]").forEach(item => {
      item.addEventListener("click", (e) => {
        e.stopPropagation()
        this.handleAction(e.currentTarget.dataset.actionType)
        this.hide()
      })
    })
  }

  hide() {
    if (this.menu) { this.menu.remove(); this.menu = null }
  }

  handleAction(action) {
    if (!this.activeRow) return

    switch (action) {
      case "editCell": {
        const editable = findEditableInCell(this.activeCell) || getEditableCells(this.activeRow)[0]
        if (editable) editable.click()
        else this.showToast("This cell is not editable")
        break
      }

      case "copyCell": {
        const source = findEditableInCell(this.activeCell) || this.activeCell
        if (!source) break
        this.copiedCellText = source.textContent.trim()
        this.copiedCellHTML = source.innerHTML.trim()
        navigator.clipboard.writeText(this.copiedCellText).catch(() => {})
        localStorage.setItem("spreadsheet_copied_cell_text", this.copiedCellText)
        localStorage.setItem("spreadsheet_copied_cell_html", this.copiedCellHTML)
        this.activeCell?.classList.add("cell-copied")
        setTimeout(() => this.activeCell?.classList.remove("cell-copied"), 1500)
        this.showToast("Cell copied ✓")
        break
      }

      case "pasteCell": {
        const html = this.copiedCellHTML || localStorage.getItem("spreadsheet_copied_cell_html")
        const text = this.copiedCellText || localStorage.getItem("spreadsheet_copied_cell_text")
        if (!text) { this.showToast("Nothing to paste. Copy a cell first."); return }
        const editable = findEditableInCell(this.activeCell)
        if (!editable) { this.showToast("This cell is not editable"); return }
        pasteCellContent(editable, html || text)
        break
      }

      case "copyRow": {
        const { rowData, tabText, flatCount } = readRow(this.activeRow)
        this.copiedRowData = rowData
        navigator.clipboard.writeText(tabText).catch(() => {})
        localStorage.setItem("spreadsheet_copied_row_data", JSON.stringify(rowData))
        this.activeRow.classList.add("cell-copied")
        setTimeout(() => this.activeRow?.classList.remove("cell-copied"), 1500)
        this.showToast(`Row copied ✓ (${flatCount} cells)`)
        break
      }

      case "pasteRow": {
        const rowData = this.resolveRowData()
        if (!rowData) { this.showToast("Nothing to paste. Copy a row first."); return }
        pasteRow(this.activeRow, rowData).then(({ pastedCount, totalToPaste }) => {
          this.showToast(`Pasted ${pastedCount}/${totalToPaste} mapped cells ✓`)
        })
        break
      }

      case "clearCell": {
        const editable = findEditableInCell(this.activeCell)
        if (!editable) { this.showToast("This cell is not editable"); return }
        saveCell(this.activeRow, editable, "-")
        this.showToast("Cell cleared ✓")
        break
      }

      case "insertBelow": {
        const icon = this.activeRow.querySelector(".bi-plus-circle-fill")
        if (icon) clickFormOrIcon(icon)
        else this.showToast("Cannot insert row here")
        break
      }

      case "history": {
        this.openCellHistory()
        break
      }

      case "archive": {
        clickFormOrIcon(this.activeRow.querySelector(".bi-archive"))
        break
      }

      case "delete": {
        this.deleteRow()
        break
      }

      case "mergeRow": {
        const fgEl = this.activeRow.querySelector('[data-controller~="function-group"]')
        if (!fgEl) { this.showToast("Merge not available for this row"); break }
        const ctrl = this.application.getControllerForElementAndIdentifier(fgEl, "function-group")
        if (ctrl) ctrl.mergeExternal()
        else this.showToast("Merge: controller not ready")
        break
      }

      case "splitRow": {
        const fgEl = this.activeRow.querySelector('[data-controller~="function-group"]')
        if (!fgEl) { this.showToast("Split not available for this row"); break }
        const ctrl = this.application.getControllerForElementAndIdentifier(fgEl, "function-group")
        if (ctrl) ctrl.splitExternal()
        else this.showToast("Split: controller not ready")
        break
      }

      case "setGroupDescription": {
        this.openGroupDescriptionModal()
        break
      }

      case "cloneRow": {
        const tcId = this.activeRow.dataset.testCaseId
        const modalEl = document.getElementById("cloneTestCasesModal")
        if (!tcId || !modalEl) { this.showToast("Clone modal not available on this page"); break }
        const ctrl = this.application.getControllerForElementAndIdentifier(modalEl, "clone-test-cases")
        if (ctrl) ctrl.setSelected([tcId])
        if (window.bootstrap) {
          const modal = window.bootstrap.Modal.getOrCreateInstance(modalEl)
          modal.show()
        }
        break
      }
    }
  }

  openGroupDescriptionModal() {
    const row = this.activeRow
    if (!row) return

    let tcId, projectId, taskId, currentValue

    if (row.classList.contains('test-case-group-header-row')) {
      tcId = row.dataset.testCaseId
      projectId = row.dataset.projectId
      taskId = row.dataset.taskId
      currentValue = row.querySelector('.group-description-display')?.innerText?.trim() || ''
    } else if (row.classList.contains('test-case-row')) {
      tcId = row.dataset.testCaseId
      projectId = row.dataset.projectId
      taskId = row.dataset.taskId
      // Scan upward to find the nearest group header row
      let prevEl = row.previousElementSibling
      currentValue = ''
      while (prevEl) {
        if (prevEl.classList.contains('test-case-group-header-row')) {
          currentValue = prevEl.querySelector('.group-description-display')?.innerText?.trim() || ''
          break
        }
        prevEl = prevEl.previousElementSibling
      }
    } else {
      this.showToast("Cannot set group description here")
      return
    }

    const modalEl = document.getElementById('groupDescriptionModal')
    if (!modalEl) { this.showToast("Modal not available"); return }

    const textarea = modalEl.querySelector('#groupDescriptionInput')
    textarea.value = currentValue

    // Replace save button to clear old event listeners
    const oldSaveBtn = modalEl.querySelector('#groupDescriptionSave')
    const saveBtn = oldSaveBtn.cloneNode(true)
    oldSaveBtn.parentNode.replaceChild(saveBtn, oldSaveBtn)

    saveBtn.addEventListener('click', () => {
      const value = textarea.value.trim()
      const url = `/projects/${projectId}/tasks/${taskId}/test_cases/${tcId}`
      const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content

      saveBtn.disabled = true
      saveBtn.textContent = 'Saving...'

      fetch(url, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': csrfToken,
          'Accept': 'text/vnd.turbo-stream.html'
        },
        body: JSON.stringify({ test_case: { group_description: value } })
      })
      .then(response => {
        if (!response.ok) throw new Error('Save failed')
        return response.text()
      })
      .then(html => {
        window.bootstrap?.Modal.getInstance(modalEl)?.hide()
        Turbo.renderStreamMessage(html)
      })
      .catch(() => {
        this.showToast("Failed to save group description")
        saveBtn.disabled = false
        saveBtn.textContent = 'Save'
      })
    })

    window.bootstrap?.Modal.getOrCreateInstance(modalEl)?.show()
  }

  openCellHistory() {
    const cell = this.activeCell
    const row = this.activeRow
    if (!cell || !row) { this.showToast("Select a cell to view history"); return }

    const field = cell.dataset.cellField
    if (!field) { this.showToast("This cell has no tracked history"); return }

    const url = row.dataset.historyUrl
    const revertUrl = row.dataset.historyRevertUrl
    if (!url) { this.showToast("History endpoint not configured"); return }

    const contentEl = cell.querySelector("[data-content-id]")
    const contentId = contentEl ? contentEl.dataset.contentId : null

    import("helpers/cell_history_popover").then(mod => {
      mod.openCellHistoryPopover({ anchor: cell, url, field, contentId, revertUrl })
    }).catch(err => {
      console.error("Failed to load cell_history_popover:", err)
      this.showToast("Failed to load history module")
    })
  }

  deleteRow() {
    const row = this.activeRow
    if (!row) return

    const tcId = row.dataset.testCaseId
    const projectId = row.dataset.projectId
    const taskId = row.dataset.taskId
    if (!tcId || !projectId || !taskId) { this.showToast("Cannot delete this row"); return }

    if (!window.confirm("Xoá vĩnh viễn test case này? Hành động này không thể hoàn tác.")) return

    // Preserve the archived view + current page so the rebuilt table matches.
    const search = new URLSearchParams(window.location.search)
    const showArchived = search.get("show_archived") || "1"
    const tcPage = search.get("tc_page") || "1"
    const url = `/projects/${projectId}/tasks/${taskId}/test_cases/${tcId}` +
                `?show_archived=${showArchived}&tc_page=${tcPage}`
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content

    fetch(url, {
      method: "DELETE",
      headers: { "X-CSRF-Token": csrfToken, "Accept": "text/vnd.turbo-stream.html" }
    })
      .then(response => {
        if (!response.ok) throw new Error("Delete failed")
        return response.text()
      })
      .then(html => { window.Turbo?.renderStreamMessage(html) })
      .catch(() => this.showToast("Xoá test case thất bại"))
  }

  resolveRowData() {
    if (this.copiedRowData && Object.keys(this.copiedRowData).length > 0) return this.copiedRowData
    try {
      const stored = localStorage.getItem("spreadsheet_copied_row_data")
      if (stored) {
        const parsed = JSON.parse(stored)
        if (Object.keys(parsed).length > 0) return parsed
      }
    } catch (e) {}
    return null
  }

  showToast(message) { showSpreadsheetToast(message) }
}
