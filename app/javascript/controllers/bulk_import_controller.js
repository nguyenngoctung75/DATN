import { Controller } from "@hotwired/stimulus"
import { csrfFetch } from 'helpers/fetch_helper'
import { getPresetRange, formatDate } from 'helpers/redmine_filter'
import { renderTableRows } from 'helpers/bulk_table_renderer'

// Bulk Import modal: load Redmine issues list with date filter, show table with imported/not imported status, import selected.
export default class extends Controller {
  static targets = [
    "listTab",
    "tableTab",
    "listPanel",
    "urlInput",
    "redmineProjectIdInput",
    "redmineProjectFallbackWrap",
    "redmineProjectFallbackInput",
    "startDate",
    "endDate",
    "datePreset",
    "loadButton",
    "tableContainer",
    "tableBody",
    "filterSelect",
    "importForm",
    "selectedCount",
    "progress",
    "submitButton",
    "cancelButton",
    "loadingIndicator"
  ]

  static values = {
    listUrl: String,
    importUrl: String
  }

  connect() {
    this.issues = []
    this.setDefaultDateRange()
  }

  onRedmineProjectChange() {
    this.toggleRedmineProjectFallback()
    const v = this.redmineProjectIdInputTarget?.value?.trim() || ""
    if (v && v !== "__custom__") {
      this.loadList()
    }
  }

  toggleRedmineProjectFallback() {
    const isCustom = this.redmineProjectIdInputTarget?.value === "__custom__"
    if (this.hasRedmineProjectFallbackWrapTarget) {
      this.redmineProjectFallbackWrapTarget.classList.toggle("d-none", !isCustom)
    }
  }

  getRedmineProjectIdValue() {
    const sel = this.redmineProjectIdInputTarget
    if (!sel) return ""
    const v = sel.value?.trim() || ""
    if (v === "__custom__") {
      return this.hasRedmineProjectFallbackInputTarget ? this.redmineProjectFallbackInputTarget.value?.trim() || "" : ""
    }
    return v
  }

  setDefaultDateRange() {
    const range = getPresetRange("last_30_days")
    if (this.hasStartDateTarget) this.startDateTarget.value = formatDate(range.start)
    if (this.hasEndDateTarget) this.endDateTarget.value = formatDate(range.end)
    if (this.hasDatePresetTarget) this.datePresetTarget.value = "last_30_days"
  }

  selectPreset(event) {
    const preset = event.currentTarget.dataset.preset
    const range = getPresetRange(preset)
    if (this.hasStartDateTarget) this.startDateTarget.value = formatDate(range.start)
    if (this.hasEndDateTarget) this.endDateTarget.value = formatDate(range.end)
    if (this.hasDatePresetTarget) this.datePresetTarget.value = preset

    // Auto-reload if project is selected
    if (this.getRedmineProjectIdValue()) {
      this.loadList()
    }
  }

  async loadList(event) {
    if (event) event.preventDefault()
    const url = this.urlInputTarget?.value?.trim() || ""
    const redmineProjectId = this.getRedmineProjectIdValue()
    const start = this.startDateTarget?.value || ""
    const end = this.endDateTarget?.value || ""
    const preset = this.datePresetTarget?.value || ""

    if (!redmineProjectId) {
      alert("Please select a Redmine Project or enter an ID/identifier.")
      return
    }

    const params = new URLSearchParams()
    if (url) params.set("issues_url", url)
    params.set("redmine_project_id", redmineProjectId)
    if (preset) params.set("date_preset", preset)
    if (start) params.set("start_date", start)
    if (end) params.set("end_date", end)

    const listUrl = `${this.listUrlValue}?${params.toString()}`

    // Hide table and show loader
    if (this.hasTableContainerTarget) this.tableContainerTarget.classList.add("d-none")
    if (this.hasLoadingIndicatorTarget) this.loadingIndicatorTarget.classList.remove("d-none")

    try {
      const resp = await csrfFetch(listUrl, {
        headers: { Accept: "application/json", "X-Requested-With": "XMLHttpRequest" }
      })
      const data = await resp.json().catch(() => ({}))
      this.issues = data.issues || []
      if (data.errors && data.errors.length > 0) {
        alert(data.errors.join("\n"))
      }
      this.renderTable()
      this.showTableTab()
    } catch (e) {
      alert("Cannot load list: " + (e.message || "Network error"))
    } finally {
      if (this.hasLoadingIndicatorTarget) this.loadingIndicatorTarget.classList.add("d-none")
    }
  }

  showTableTab() {
    if (this.hasTableContainerTarget) this.tableContainerTarget.classList.remove("d-none")
  }

  showListTab(event) {
    if (event) event.preventDefault()
    if (this.hasTableTabTarget) this.tableTabTarget.classList.remove("active")
    if (this.hasListTabTarget) this.listTabTarget.classList.add("active")
    if (this.hasListPanelTarget) this.listPanelTarget.classList.remove("d-none")
    if (this.hasTableContainerTarget) this.tableContainerTarget.classList.add("d-none")
  }

  renderTable() {
    if (!this.hasTableBodyTarget) return
    this.tableBodyTarget.innerHTML = renderTableRows(this.issues, this.filterSelectTarget?.value || "all")
    this.updateSelectedCount()
  }

  filterTable() { this.renderTable() }

  updateSelectedCount() {
    if (!this.hasSelectedCountTarget) return
    this.selectedCountTarget.textContent = this.element.querySelectorAll(".bulk-import-checkbox:checked").length
  }

  toggleAll(event) {
    this.element.querySelectorAll(".bulk-import-checkbox").forEach(cb => (cb.checked = event.target.checked))
    this.updateSelectedCount()
  }

  submitImport(event) {
    event.preventDefault()
    const form = this.hasImportFormTarget ? this.importFormTarget : this.element.querySelector("form[action*='import_selected']")
    if (!form) return
    const checked = this.element.querySelectorAll(".bulk-import-checkbox:checked")
    if (checked.length === 0) {
      alert("Please select at least one task that hasn't been imported.")
      return
    }
    form.querySelectorAll('input[name="issue_ids[]"]').forEach(el => el.remove())
    checked.forEach(cb => {
      const input = Object.assign(document.createElement("input"), { type: "hidden", name: "issue_ids[]", value: cb.value })
      form.appendChild(input)
    })
    if (this.hasProgressTarget) this.progressTarget.classList.remove("d-none")
    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.disabled = true
      this.submitButtonTarget.innerHTML = '<span class="spinner-border spinner-border-sm me-2"></span>Importing...'
    }
    if (this.hasCancelButtonTarget) this.cancelButtonTarget.disabled = true
    form.requestSubmit()
  }
}
