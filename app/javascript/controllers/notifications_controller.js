import { Controller } from "@hotwired/stimulus"
import { createConsumer } from "@rails/actioncable"

// Subscribes to UserChannel and updates notification dropdown in realtime.
export default class extends Controller {
  static values = {
    readAndGoPath: { type: String, default: "/notifications" }
  }

  static targets = ["badge", "list", "emptyMessage"]

  connect() {
    var meta = document.querySelector("meta[name='action-cable-url']")
    var cableUrl = (meta && meta.getAttribute("content")) || "/cable"
    this.consumer = createConsumer(cableUrl)
    this.subscription = this.consumer.subscriptions.create("UserChannel", {
      received: (function(data) {
        if (data && data.event === "notification") {
          this.updateNotification(data.data)
        }
      }).bind(this)
    })
  }

  disconnect() {
    if (this.subscription) {
      this.consumer.subscriptions.remove(this.subscription)
    }
  }

  updateNotification(data) {
    if (!data || !data.id) return

    const link = `${this.readAndGoPathValue}/${data.id}/read_and_go`
    const goUrl = data.link || link
    const timeAgo = this.timeAgo(data.created_at)
    const itemClass = data.category === "cronjob" ? "dropdown-item py-2 bg-light notification-item notification-item-unread" : "dropdown-item py-2 notification-item notification-item-unread"
    const message = data.message ? `<div class="small text-muted mt-1 text-break" style="word-break: break-word;">${this.escapeHtml(data.message)}</div>` : ""

    const li = document.createElement("li")
    li.className = "notification-dropdown-item"
    li.innerHTML = `
      <a href="${this.escapeHtml(link)}" class="${itemClass}" data-notification-id="${this.escapeHtml(String(data.id))}" data-link="${this.escapeHtml(goUrl || "")}">
        <div class="d-flex w-100 justify-content-between gap-2 align-items-start">
          <span class="small fw-semibold text-break" style="min-width: 0;">${this.escapeHtml(data.title || "")}</span>
          <span class="small text-muted flex-shrink-0">${timeAgo}</span>
        </div>
        ${message}
      </a>
    `
    li.querySelector("a").addEventListener("click", (e) => {
      e.currentTarget.setAttribute("data-turbo", "false")
    })

    if (this.hasListTarget) {
      if (this.hasEmptyMessageTarget && this.emptyMessageTarget.closest("li")) {
        this.emptyMessageTarget.closest("li").remove()
      } else {
        const emptyLi = this.listTarget.querySelector("li .dropdown-item.text-muted")
        if (emptyLi && emptyLi.textContent && emptyLi.textContent.trim() === "No new notification") {
          emptyLi.closest("li").remove()
        }
      }
      this.listTarget.insertBefore(li, this.listTarget.firstElementChild)
    }

    if (this.hasBadgeTarget) {
      const n = parseInt(this.badgeTarget.textContent.replace(/\D/g, ""), 10) || 0
      const next = n + 1
      this.badgeTarget.textContent = next > 99 ? "99+" : String(next)
      this.badgeTarget.style.display = ""
    }

    if (data.category === "cronjob" && typeof window.showToast === "function" && data.link) {
      this.showCronjobToast(data.title, data.message || data.title, data.link)
    }
  }

  timeAgo(iso) {
    if (!iso) return ""
    const date = new Date(iso)
    const sec = Math.floor((Date.now() - date.getTime()) / 1000)
    if (sec < 60) return "vừa xong"
    if (sec < 3600) return `${Math.floor(sec / 60)} phút trước`
    if (sec < 86400) return `${Math.floor(sec / 3600)} giờ trước`
    return `${Math.floor(sec / 86400)} ngày trước`
  }

  escapeHtml(str) {
    if (str == null) return ""
    const div = document.createElement("div")
    div.textContent = str
    return div.innerHTML
  }

  showCronjobToast(title, message, link) {
    if (typeof window.showToast !== "function") return
    const fullMessage = message && message !== title ? title + " — " + message : title
    // Gray style like notifications page, show only a few seconds
    window.showToast(fullMessage, "secondary", 2000, { link: link })
  }
}
