import { Controller } from "@hotwired/stimulus"
import { csrfFetch } from 'helpers/fetch_helper'

// Handles click on notification links: mark as read via API, update dropdown + index UI in realtime, then redirect.
// Use event delegation so dropdown and index links (and dynamically added items) all work.
export default class extends Controller {
  connect() {
    this.markingInProgress = false
    this.boundHandleClick = this.handleClick.bind(this)
    this.boundMarkAllRead = this.markAllRead.bind(this)
    this.boundRefreshBadge = this.refreshBadgeFromServer.bind(this)
    document.addEventListener("click", this.boundHandleClick, true)
    document.addEventListener("submit", this.boundMarkAllRead, true)
    document.addEventListener("turbo:load", this.boundRefreshBadge)
    this.refreshBadgeFromServer()
  }

  disconnect() {
    document.removeEventListener("click", this.boundHandleClick, true)
    document.removeEventListener("submit", this.boundMarkAllRead, true)
    document.removeEventListener("turbo:load", this.boundRefreshBadge)
  }

  refreshBadgeFromServer() {
    csrfFetch("/notifications/unread_count", { credentials: "same-origin" })
      .then((r) => r.json())
      .then((data) => {
        const n = data.unread_count != null ? data.unread_count : 0
        this.updateBadge(n)
      })
      .catch(() => {})
  }

  markAllRead(event) {
    const form = event.target
    if (form.tagName !== "FORM" || !form.action || !String(form.action).includes("mark_all_read")) return
    const method = (form.method || "get").toLowerCase()
    if (method !== "post") return
    event.preventDefault()
    event.stopPropagation()
    const url = form.action.includes("http") ? form.action : (window.location.origin + (form.action.startsWith("/") ? form.action : "/" + form.action))
    csrfFetch(url, { method: "POST", credentials: "same-origin" })
      .then((r) => r.json())
      .then((data) => {
        document.querySelectorAll("[data-notification-id]").forEach((el) => {
          if (el.classList.contains("notification-item-unread")) {
            el.classList.remove("notification-item-unread")
            el.classList.add("notification-item-read")
          }
          if (el.classList.contains("notification-unread")) el.classList.remove("notification-unread")
          el.classList.add("notification-read")
          const li = el.closest("li")
          if (li) { li.classList.remove("notification-unread"); li.classList.add("notification-read") }
          const title = el.querySelector(".fw-semibold")
          if (title) { title.classList.remove("fw-semibold"); title.classList.add("fw-normal") }
          el.classList.remove("text-dark")
          el.classList.add("text-muted")
        })
        this.updateBadge(0)
      })
      .catch(() => window.location.reload())
  }

  handleClick(event) {
    const link = event.target.closest("a[data-notification-id]")
    if (!link) return
    if (this.markingInProgress) return

    const id = link.getAttribute("data-notification-id")
    const redirectUrl = link.getAttribute("data-link") || link.getAttribute("href") || "/"
    if (!id) return

    event.preventDefault()
    event.stopPropagation()
    event.stopImmediatePropagation()
    this.markReadAndGo(id, redirectUrl)
  }

  async markReadAndGo(notificationId, redirectUrl) {
    if (this.markingInProgress) return
    this.markingInProgress = true

    const url = `/notifications/${notificationId}/mark_read`

    try {
      const res = await csrfFetch(url, { method: "POST" })
      const data = await res.json().catch(() => ({}))
      if (!res.ok) throw new Error(data.error || "Mark read failed")

      const unreadCount = data.unread_count != null ? data.unread_count : 0
      this.setReadStyleForNotification(notificationId)
      this.updateBadge(unreadCount)
      window.location.href = redirectUrl
    } catch {
      this.markingInProgress = false
      window.location.href = redirectUrl
    }
  }

  setReadStyleForNotification(notificationId) {
    const selector = `[data-notification-id="${notificationId}"]`
    document.querySelectorAll(selector).forEach((el) => {
      if (el.classList.contains("notification-item-unread")) {
        el.classList.remove("notification-item-unread")
        el.classList.add("notification-item-read")
      }
      if (el.classList.contains("notification-unread")) {
        el.classList.remove("notification-unread")
        el.classList.add("notification-read")
      }
      const li = el.closest("li")
      if (li) {
        li.classList.remove("notification-unread")
        li.classList.add("notification-read")
      }
      const title = el.querySelector(".fw-semibold")
      if (title) {
        title.classList.remove("fw-semibold")
        title.classList.add("fw-normal")
      }
      if (el.classList.contains("text-dark")) {
        el.classList.remove("text-dark")
        el.classList.add("text-muted")
      }
    })
  }

  updateBadge(count) {
    const badge = document.querySelector("[data-notification-badge]")
    if (!badge) return
    const n = parseInt(count, 10) || 0
    badge.textContent = n > 99 ? "99+" : String(n)
    badge.style.display = n > 0 ? "" : "none"
  }
}
