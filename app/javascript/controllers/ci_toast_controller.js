import { Controller } from "@hotwired/stimulus"
import { createConsumer } from "@rails/actioncable"

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
    requestAnimationFrame(() => toast.classList.add("ci-toast--visible"))

    setTimeout(() => this.dismiss(toast), this.dismissAfterValue)
  }

  dismiss(toast) {
    if (!toast.isConnected) return
    toast.classList.remove("ci-toast--visible")
    toast.addEventListener("transitionend", () => toast.remove(), { once: true })
    setTimeout(() => toast.remove(), 400)
  }

  escape(s) {
    return String(s ?? "").replace(/[&<>"']/g, (c) => (
      { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]
    ))
  }
}
