import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["sidebar", "content", "toggleIcon"]

  connect() {
    const isCollapsed = localStorage.getItem("sidebar-collapsed") === "true"
    if (isCollapsed) {
      this.applyCollapsedState(true)
    }
  }

  toggle(event) {
    if (event) event.preventDefault()
    const willCollapse = !this.sidebarTarget.classList.contains("collapsed")
    this.applyCollapsedState(willCollapse)
    localStorage.setItem("sidebar-collapsed", willCollapse)
  }

  applyCollapsedState(collapsed) {
    if (collapsed) {
      this.sidebarTarget.classList.add("collapsed")
      this.toggleIconTarget.classList.remove("bi-layout-sidebar-inset")
      this.toggleIconTarget.classList.add("bi-layout-sidebar")
    } else {
      this.sidebarTarget.classList.remove("collapsed")
      this.toggleIconTarget.classList.remove("bi-layout-sidebar")
      this.toggleIconTarget.classList.add("bi-layout-sidebar-inset")
    }
  }
}
