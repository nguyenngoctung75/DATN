import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form", "hiddenIds", "sourceCountLabel", "submitButton"]
  static values  = { taskLabel: String, taskId: String }

  connect() {
    this.selectedIds = []
    this.element.addEventListener("hidden.bs.modal", this.onClose.bind(this))
  }

  setSelected(ids) {
    this.selectedIds = (ids || []).map(String).filter(Boolean)
    this.renderHidden()
    this.updateLabel()
  }

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
