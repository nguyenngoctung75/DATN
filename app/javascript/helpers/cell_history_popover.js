import { csrfFetch } from "helpers/fetch_helper"
import { toastError } from "helpers/toast_helper"

let activeInstance = null

export async function openCellHistoryPopover({ anchor, url, field, contentId, revertUrl }) {
  if (activeInstance) {
    activeInstance.dispose()
    activeInstance = null
  }

  const fetchUrl = new URL(url, window.location.origin)
  fetchUrl.searchParams.set("field", field)
  if (contentId) fetchUrl.searchParams.set("content_id", contentId)

  let versions
  try {
    const res = await csrfFetch(fetchUrl.toString(), { headers: { Accept: "application/json" } })
    if (!res.ok) throw new Error(`HTTP ${res.status}`)
    versions = await res.json()
  } catch (e) {
    toastError(`Failed to load history: ${e.message}`)
    return
  }

  if (!versions.length) {
    toastError("No history for this cell yet")
    return
  }

  const state = { versions, index: 0, anchor, field, contentId, revertUrl }
  activeInstance = createPopover(state)
}

function createPopover(state) {
  if (!window.bootstrap || !window.bootstrap.Popover) {
    toastError("Bootstrap not loaded")
    return null
  }

  const pop = new window.bootstrap.Popover(state.anchor, {
    html: true,
    sanitize: false,
    trigger: "manual",
    placement: "bottom",
    customClass: "cell-history-popover",
    container: "body",
    content: () => renderBody(state)
  })

  const dispose = () => {
    document.removeEventListener("click", onOutside, true)
    document.removeEventListener("keydown", onEsc)
    try { pop.dispose() } catch (_) {}
    if (activeInstance && activeInstance.dispose === dispose) activeInstance = null
  }

  const onOutside = (e) => {
    if (state.anchor.contains(e.target)) return
    const tip = pop.tip
    if (tip && tip.contains(e.target)) return
    dispose()
  }

  const onEsc = (e) => { if (e.key === "Escape") dispose() }

  pop.show()

  requestAnimationFrame(() => {
    bindNav(pop, state, dispose)
    document.addEventListener("click", onOutside, true)
    document.addEventListener("keydown", onEsc)
  })

  return { dispose }
}

function renderBody(state) {
  const v = state.versions[state.index]
  const isFirst = state.index <= 0
  const isLast = state.index >= state.versions.length - 1

  return `
    <div class="ch-header">
      <span class="ch-avatar">${escapeHTML(v.user_initial)}</span>
      <div class="ch-meta">
        <div class="fw-semibold">${escapeHTML(v.user_name)}</div>
        <div class="ch-time">${escapeHTML(v.time_ago)}</div>
      </div>
      <span class="badge bg-secondary ms-auto">${escapeHTML(v.action_type)}</span>
      <button type="button" class="btn-close ms-2" data-ch="close" aria-label="Close" style="font-size:0.7rem"></button>
    </div>
    <div class="ch-diff">
      <div class="ch-label">Previous:</div>
      <div class="ch-old">${v.old_value || "<em class='text-muted'>empty</em>"}</div>
      <div class="ch-label">Current:</div>
      <div class="ch-new">${v.new_value || "<em class='text-muted'>empty</em>"}</div>
    </div>
    <div class="ch-nav">
      <button data-ch="prev" ${isLast ? "disabled" : ""}>&#8592; Older</button>
      <span class="ch-pos">${state.index + 1} / ${state.versions.length}</span>
      <button data-ch="next" ${isFirst ? "disabled" : ""}>Newer &#8594;</button>
      <button data-ch="restore" class="btn btn-sm btn-outline-warning py-0 ms-1" ${v.can_restore ? "" : "disabled"} title="Restore to previous value">&#8635; Restore</button>
    </div>`
}

function bindNav(pop, state, dispose) {
  const tip = pop.tip
  if (!tip) return

  tip.querySelectorAll("[data-ch]").forEach(btn => {
    btn.addEventListener("click", async (e) => {
      e.stopPropagation()
      const action = btn.dataset.ch

      if (action === "close") {
        dispose()
        return
      }

      if (action === "prev" || action === "next") {
        const delta = action === "prev" ? 1 : -1
        const next = Math.max(0, Math.min(state.versions.length - 1, state.index + delta))
        if (next === state.index) return
        state.index = next
        const body = tip.querySelector(".popover-body")
        if (body) {
          body.innerHTML = renderBody(state)
          bindNav(pop, state, dispose)
        }
        return
      }

      if (action === "restore") {
        await restoreVersion(state, dispose)
      }
    })
  })
}

async function restoreVersion(state, dispose) {
  const v = state.versions[state.index]
  if (!confirm(`Restore "${state.field}" to previous value?`)) return

  const fd = new FormData()
  fd.append("log_id", v.id)
  fd.append("field", state.field)
  if (state.contentId) fd.append("content_id", state.contentId)

  new URLSearchParams(window.location.search).forEach((value, key) => {
    if (!fd.has(key)) fd.append(key, value)
  })

  try {
    const res = await csrfFetch(state.revertUrl, {
      method: "POST",
      body: fd,
      headers: { Accept: "text/vnd.turbo-stream.html" }
    })

    if (res.ok) {
      const html = await res.text()
      Turbo.renderStreamMessage(html)
      dispose()
    } else {
      const data = await res.json().catch(() => ({}))
      toastError(data.error || "Restore failed")
    }
  } catch (e) {
    toastError(`Restore failed: ${e.message}`)
  }
}

function escapeHTML(s) {
  return String(s).replace(/[&<>"']/g, c => ({
    "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;"
  }[c]))
}
