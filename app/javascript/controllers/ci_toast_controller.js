import { Controller } from "@hotwired/stimulus"
import { createConsumer } from "@rails/actioncable"

// Subscribes to UserChannel (which streams `notifications`) and renders a
// prominent top-right toast for CI/CD events. The header dropdown is still
// updated by notifications_controller.js — this controller adds the extra
// visual surface for CI events only.
//
// Filter contract: only handles messages whose data.kind === "ci". That field
// is set by Notification#broadcast_payload when the title starts with "✅ CI "
// or "❌ CI ".
export default class extends Controller {
  static values = { dismissAfter: { type: Number, default: 7000 } }

  connect() {
    const meta = document.querySelector("meta[name='action-cable-url']")
    const cableUrl = (meta && meta.getAttribute("content")) || "/cable"
    this.consumer = createConsumer(cableUrl)
    this.subscription = this.consumer.subscriptions.create("UserChannel", {
      received: (msg) => {
        if (msg?.event !== "notification") return
        if (msg.data?.kind !== "ci") return
        this.render(msg.data)
      }
    })
  }

  disconnect() {
    if (this.subscription) {
      this.consumer.subscriptions.remove(this.subscription)
    }
    this.consumer?.disconnect()
  }

  render(data) {
    const ok = String(data.title || "").startsWith("✅")
    const toast = document.createElement("div")
    toast.className = `ci-toast ci-toast--${ok ? "ok" : "fail"}`
    toast.setAttribute("role", "alert")
    toast.innerHTML = `
      <button class="ci-toast__close" aria-label="Close">×</button>
      <div class="ci-toast__title">${this.escape(data.title)}</div>
      <div class="ci-toast__msg">${this.escape(data.message || "")}</div>
      ${data.link ? `<a class="ci-toast__link" href="${this.escape(data.link)}" target="_blank" rel="noopener">View on GitHub →</a>` : ""}
    `
    toast.querySelector(".ci-toast__close")
         .addEventListener("click", () => this.dismiss(toast))

    this.element.appendChild(toast)
    // Defer to next frame so the CSS transition has a "before" state to animate from.
    requestAnimationFrame(() => toast.classList.add("ci-toast--visible"))

    setTimeout(() => this.dismiss(toast), this.dismissAfterValue)
  }

  dismiss(toast) {
    if (!toast.isConnected) return
    toast.classList.remove("ci-toast--visible")
    toast.addEventListener("transitionend", () => toast.remove(), { once: true })
    // Safety net: if for any reason transitionend never fires, force-remove.
    setTimeout(() => toast.remove(), 400)
  }

  escape(s) {
    return String(s ?? "").replace(/[&<>"']/g, (c) => (
      { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]
    ))
  }
}
