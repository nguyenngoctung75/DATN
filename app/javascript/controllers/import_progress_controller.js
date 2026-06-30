import { Controller } from "@hotwired/stimulus"
import { createConsumer } from "@rails/actioncable"
import { csrfFetch } from "helpers/fetch_helper"

export default class extends Controller {
  static targets = [
    "form", "progress", "submitButton", "cancelButton",
    "progressBar", "statusBadge", "statusText",
    "processedCount", "totalCount", "importedCount",
    "errorBox", "logBox"
  ]

  static values = {
    importRunId: { type: Number, default: 0 },
    statusUrl: { type: String, default: "" },
    pollIntervalMs: { type: Number, default: 3000 }
  }

  connect() {
    if (this.importRunIdValue > 0) {
      this.subscribe()
      this.startPolling()
    }
  }

  disconnect() {
    if (this.subscription) {
      this.consumer.subscriptions.remove(this.subscription)
      this.subscription = null
    }
    this.stopPolling()
  }

  showProgress() {
    if (this.hasProgressTarget) {
      this.progressTarget.classList.remove("d-none")
    }
    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.disabled = true
      this.submitButtonTarget.innerHTML = `
        <span class="spinner-border spinner-border-sm me-2" role="status" aria-hidden="true"></span>
        Importing...
      `
    }
    if (this.hasCancelButtonTarget) {
      this.cancelButtonTarget.disabled = true
    }
  }

  subscribe() {
    const meta = document.querySelector("meta[name='action-cable-url']")
    const cableUrl = (meta && meta.getAttribute("content")) || "/cable"
    this.consumer = createConsumer(cableUrl)
    this.subscription = this.consumer.subscriptions.create("UserChannel", {
      received: (data) => this.handleEvent(data)
    })
  }

  handleEvent(data) {
    if (!data || data.import_run_id !== this.importRunIdValue) return
    if (!["import_started", "import_progress", "import_complete", "import_failed"].includes(data.event)) return

    this.applyState(data)

    if (data.event === "import_complete" || data.event === "import_failed") {
      this.stopPolling()
      this.notifyCompletion(data)
    }
  }

  startPolling() {
    if (!this.statusUrlValue) return
    this.pollTimer = setInterval(() => this.pollOnce(), this.pollIntervalMsValue)
  }

  stopPolling() {
    if (this.pollTimer) {
      clearInterval(this.pollTimer)
      this.pollTimer = null
    }
  }

  async pollOnce() {
    try {
      const res = await csrfFetch(this.statusUrlValue, { headers: { "Accept": "application/json" } })
      if (!res.ok) return
      const data = await res.json()
      this.applyState(data)
      if (data.status === "success" || data.status === "failed") {
        this.stopPolling()
      }
    } catch (_) {
    }
  }

  applyState(data) {
    if (this.hasProgressBarTarget && typeof data.progress_percent === "number") {
      const pct = Math.max(0, Math.min(100, data.progress_percent))
      this.progressBarTarget.style.width = `${pct}%`
      this.progressBarTarget.setAttribute("aria-valuenow", pct)
      this.progressBarTarget.textContent = `${pct}%`
    }
    if (this.hasProcessedCountTarget) {
      this.processedCountTarget.textContent = data.processed_count ?? 0
    }
    if (this.hasTotalCountTarget) {
      this.totalCountTarget.textContent = data.total_count ?? 0
    }
    if (this.hasImportedCountTarget) {
      this.importedCountTarget.textContent = data.imported_count ?? 0
    }
    if (this.hasStatusBadgeTarget && data.status) {
      this.statusBadgeTarget.textContent = data.status
      this.statusBadgeTarget.className = `badge ${this.badgeClassFor(data.status)}`
    }
    if (this.hasStatusTextTarget && (data.status === "success" || data.status === "failed")) {
      this.statusTextTarget.textContent = data.status === "success" ? "Finished." : "Failed."
    }
    if (this.hasErrorBoxTarget && data.error_message) {
      this.errorBoxTarget.classList.remove("d-none")
      this.errorBoxTarget.innerHTML = `<strong>Error:</strong> ${this.escapeHtml(data.error_message)}`
    }
  }

  notifyCompletion(data) {
    if (typeof window.showToast !== "function") return
    if (data.event === "import_complete") {
      window.showToast(`Import complete (${data.imported_count || 0} imported)`, "success", 4000)
    } else {
      window.showToast(`Import failed: ${data.error_message || "unknown error"}`, "danger", 6000)
    }
  }

  badgeClassFor(status) {
    if (status === "success") return "bg-success"
    if (status === "failed") return "bg-danger"
    if (status === "running") return "bg-info text-dark"
    return "bg-secondary"
  }

  escapeHtml(str) {
    if (str == null) return ""
    const div = document.createElement("div")
    div.textContent = str
    return div.innerHTML
  }
}
