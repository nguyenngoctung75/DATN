// Pure render helpers extracted from bulk_import_controller.js
import { escapeHtml } from 'helpers/redmine_filter'

export function renderTableRows(issues, filter) {
  let rows = issues
  if (filter === "not_imported") rows = rows.filter(i => !i.already_imported)
  if (filter === "imported") rows = rows.filter(i => i.already_imported)
  return rows.map(issue => buildIssueRow(issue)).join("")
}

function buildIssueRow(issue) {
  const checkbox = issue.already_imported
    ? ""
    : `<input type="checkbox" class="form-check-input bulk-import-checkbox" name="issue_ids[]" value="${issue.id}" data-action="change->bulk-import#updateSelectedCount">`
  const badge = issue.already_imported
    ? '<span class="badge bg-success">Imported</span>'
    : '<span class="badge bg-warning text-dark">Not imported</span>'

  return `
    <tr class="${issue.already_imported ? "table-secondary" : ""}" data-issue-id="${issue.id}">
      <td>${checkbox}</td>
      <td>#${issue.id}</td>
      <td>${escapeHtml(issue.subject)}</td>
      <td>${formatDisplayDate(issue.created_on)}</td>
      <td>${escapeHtml(issue.assigned_to_name)}</td>
      <td>${badge}</td>
    </tr>
  `
}

function formatDisplayDate(str) {
  if (!str) return "-"
  try {
    const d = new Date(str)
    return isNaN(d) ? str : d.toLocaleDateString("vi-VN")
  } catch {
    return str
  }
}
