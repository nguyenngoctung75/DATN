import { Controller } from "@hotwired/stimulus"
import { csrfFetch } from "helpers/fetch_helper"
import { toastError } from "helpers/toast_helper"

// Manages merge/split of test case function groups.
// merge() copies the title from the row above — no confirmation dialog needed.
// split() shows an inline input directly in the cell instead of a native prompt().
export default class extends Controller {
  static values = { testCaseId: Number, projectId: Number, taskId: Number }

  // ── Public actions (buttons + context menu) ──────────────────────────────

  merge(event) {
    event.preventDefault()
    const currentRow = this.element.closest("tr.test-case-row")
    if (!currentRow) return

    const prevTitleEl = this._findPreviousTitleEl(currentRow)
    if (!prevTitleEl) { toastError("No row above to merge with."); return }

    const prevTitle = prevTitleEl.textContent.trim()
    if (!prevTitle) { toastError("The row above has no function name."); return }

    this._saveTitle(prevTitle)
  }

  split(event) {
    event.preventDefault()
    if (this._splitting) return

    const titleEl = this.element.querySelector("[data-field='title']")
    const currentTitle = titleEl ? titleEl.textContent.trim() : ""
    this._showSplitInput(titleEl, currentTitle)
  }

  // Called by context_menu_controller via getControllerForElementAndIdentifier
  mergeExternal() { this.merge(new Event("click")) }
  splitExternal()  { this.split(new Event("click")) }

  // ── Private ──────────────────────────────────────────────────────────────

  _findPreviousTitleEl(currentRow) {
    let prevRow = currentRow.previousElementSibling
    while (prevRow) {
      if (prevRow.classList.contains("test-case-row")) {
        const el = prevRow.querySelector("[data-field='title']")
        if (el) return el
      }
      prevRow = prevRow.previousElementSibling
    }
    return null
  }

  _showSplitInput(titleEl, currentTitle) {
    this._splitting = true

    const wrapper = document.createElement("div")
    wrapper.className = "split-input-wrapper"

    const input = document.createElement("input")
    input.type = "text"
    input.className = "split-inline-input"
    input.value = currentTitle
    input.placeholder = "New function name…"
    input.setAttribute("spellcheck", "false")

    const hint = document.createElement("div")
    hint.className = "split-input-hint"
    hint.textContent = "Enter to confirm · Esc to cancel"

    wrapper.append(input, hint)

    const container = titleEl ? titleEl.parentElement : this.element.querySelector(".p-2") || this.element
    container.appendChild(wrapper)
    input.focus()
    input.select()

    const cancel = () => {
      wrapper.remove()
      this._splitting = false
    }

    const commit = () => {
      const newTitle = input.value.trim()
      wrapper.remove()
      this._splitting = false
      if (!newTitle || newTitle === currentTitle) return
      this._saveTitle(newTitle, { skipSync: true })
    }

    input.addEventListener("keydown", (e) => {
      if (e.key === "Enter")  { e.preventDefault(); e.stopPropagation(); commit() }
      if (e.key === "Escape") { e.stopPropagation(); cancel() }
      e.stopPropagation() // prevent spreadsheet keyboard nav while typing
    })

    // Delay so the Enter keydown fires before blur
    input.addEventListener("blur", () => setTimeout(() => { if (this._splitting) commit() }, 180))
  }

  _saveTitle(newTitle, options = {}) {
    const url = `/projects/${this.projectIdValue}/tasks/${this.taskIdValue}/test_cases/${this.testCaseIdValue}`
    const body = { test_case: { title: newTitle } }
    if (options.skipSync) body.skip_title_sync = true

    csrfFetch(url, { method: "PATCH", body: JSON.stringify(body) })
      .then(r => {
        if (!r.ok) return r.json().then(d => toastError("Failed: " + (d.errors || []).join(", ")))
        // Smooth Turbo reload to re-render rowspans — far less jarring than window.location.reload()
        Turbo.visit(window.location.href, { action: "replace" })
      })
      .catch(() => toastError("An error occurred while saving."))
  }
}
