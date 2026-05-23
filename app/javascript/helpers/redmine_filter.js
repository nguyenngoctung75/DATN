// Returns { start: Date, end: Date } for a named date preset.
export function getPresetRange(preset) {
  const today = new Date()
  today.setHours(0, 0, 0, 0)
  const addDays = (date, n) => {
    const r = new Date(date)
    r.setDate(r.getDate() + n)
    return r
  }
  const ranges = {
    today: { start: today, end: today },
    yesterday: { start: addDays(today, -1), end: addDays(today, -1) },
    last_7_days: { start: addDays(today, -6), end: today },
    last_30_days: { start: addDays(today, -29), end: today },
    last_90_days: { start: addDays(today, -89), end: today },
    this_month: {
      start: new Date(today.getFullYear(), today.getMonth(), 1),
      end: today
    },
    last_month: {
      start: new Date(today.getFullYear(), today.getMonth() - 1, 1),
      end: new Date(today.getFullYear(), today.getMonth(), 0)
    },
    this_year: { start: new Date(today.getFullYear(), 0, 1), end: today }
  }
  return ranges[preset] || ranges.last_30_days
}

// Formats a Date object as "YYYY-MM-DD".
export function formatDate(d) {
  const y = d.getFullYear()
  const m = String(d.getMonth() + 1).padStart(2, '0')
  const day = String(d.getDate()).padStart(2, '0')
  return `${y}-${m}-${day}`
}

// Escapes special HTML characters in a string.
export function escapeHtml(text) {
  const div = document.createElement('div')
  div.textContent = text
  return div.innerHTML
}
