import { Controller } from "@hotwired/stimulus"

// Manages the Clone Test Cases modal state.
// Receives a list of selected source TC IDs via setSelected(ids[]) before the
// modal opens; renders hidden inputs and updates the count label. When called
// with an empty array, the form submits with no source_ids and the backend
// will clone every active test case in the source task.
export default class extends Controller {
  static targets = ["form", "hiddenIds", "sourceCountLabel", "submitButton"]
  static values  = { taskLabel: String, taskId: String }

  connect() {
    this.selectedIds = []
    this.element.addEventListener("hidden.bs.modal", this.onClose.bind(this))
  }

  // Public API — call before opening the modal.
  setSelected(ids) {
    this.selectedIds = (ids || []).map(String).filter(Boolean)
    this.renderHidden()
    this.updateLabel()
  }

  // Reset state on close so reopening from a different trigger is clean.
  onClose() {
    this.selectedIds = []
    if (this.hasHiddenIdsTarget) this.hiddenIdsTarget.innerHTML = ""
    if (this.hasFormTarget) this.formTarget.reset()
  }

  renderHidden() {
    if (!this.hasHiddenIdsTarget) return
    this.hiddenIdsTarget.innerHTML = this.selectedIds.map(id => (
      `<input type="hidden" name="source_ids[]" value="${id}">`
    )).join("")
  }

  updateLabel() {
    if (!this.hasSourceCountLabelTarget) return
    if (this.selectedIds.length > 0) {
      const noun = this.selectedIds.length === 1 ? "test case" : "test cases"
      this.sourceCountLabelTarget.textContent = `${this.selectedIds.length} selected ${noun}`
    } else {
      this.sourceCountLabelTarget.textContent = `All active test cases in this task`
    }
  }
}
