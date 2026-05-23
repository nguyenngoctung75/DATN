import { csrfFetch } from 'helpers/fetch_helper'
import { toastError, toastWarning } from 'helpers/toast_helper'

// Reads all copyable column data from a row.
// Returns { rowData, tabText, flatCount }.
export function readRow(row) {
  const copyCols = Array.from(row.querySelectorAll('td[data-copy-col]'))
  const rowData = {}
  const flatText = []

  copyCols.forEach(td => {
    const colName = td.dataset.copyCol
    const cells = Array.from(td.querySelectorAll("[data-editable-cell-target='display']"))
    rowData[colName] = cells.map(cell => {
      const text = cell.textContent.trim()
      flatText.push(text)
      return { text, html: cell.innerHTML.trim(), field: cell.dataset.field || null, contentId: cell.dataset.contentId || null }
    })
  })

  return { rowData, tabText: flatText.join('\t'), flatCount: flatText.length }
}

// Opens the cell editor and pastes HTML content into it.
export function pasteCellContent(editableDisplay, htmlContent) {
  editableDisplay.click()
  setTimeout(() => {
    const input = document.querySelector("[data-editable-cell-active='true']")
    if (input) {
      input.innerHTML = htmlContent
      setTimeout(() => input.blur(), 50)
    }
  }, 150)
}

// Saves a single cell directly via PATCH API.
// Resolves to true on success, false on failure.
export function saveCell(row, display, newValue) {
  return new Promise((resolve) => {
    const field = display.dataset.field
    const contentId = display.dataset.contentId

    if (!field) {
      toastWarning('Cell has no data-field attribute, skipping')
      resolve(false)
      return
    }

    const model = row.dataset.model || 'test_case'
    const isTestCase = model === 'test_case'
    const projectId = row.dataset.projectId
    const taskId = row.dataset.taskId
    const entityId = isTestCase ? row.dataset.testCaseId : row.dataset.bugId
    const entityPath = isTestCase ? 'test_cases' : 'bugs'

    const url = (contentId && isTestCase)
      ? `/test_step_contents/${contentId}`
      : `/projects/${projectId}/tasks/${taskId}/${entityPath}/${entityId}`
    const params = (contentId && isTestCase)
      ? { test_step_content: { [field]: newValue } }
      : { [model]: { [field]: newValue } }

    csrfFetch(url, { method: 'PATCH', body: JSON.stringify(params) })
      .then(r => r.json())
      .then(data => {
        if (data.id || data.content_value !== undefined) {
          display.innerHTML = data.formatted_value || newValue
          display.classList.add('cell-saved')
          setTimeout(() => display.classList.remove('cell-saved'), 1000)
          resolve(true)
        } else {
          toastWarning('Unexpected response when saving cell')
          resolve(false)
        }
      })
      .catch(() => {
        toastError('Error saving cell')
        display.classList.add('cell-error')
        setTimeout(() => display.classList.remove('cell-error'), 2000)
        resolve(false)
      })
  })
}

// Pastes a copied row into a target row via direct API calls.
// Returns { pastedCount, totalToPaste }.
export async function pasteRow(targetRow, copiedRowData) {
  let pastedCount = 0
  let totalToPaste = 0

  for (const [colName, sourceCells] of Object.entries(copiedRowData)) {
    const targetTd = targetRow.querySelector(`td[data-copy-col="${colName}"]`)
    if (!targetTd || sourceCells.length === 0) continue

    const targetCells = Array.from(targetTd.querySelectorAll("[data-editable-cell-target='display']"))
    if (targetCells.length === 0) continue

    for (let i = 0; i < targetCells.length; i++) {
      totalToPaste++
      const targetDisplay = targetCells[i]
      let htmlToPaste = '-'

      if (i < sourceCells.length) {
        htmlToPaste = (i === targetCells.length - 1 && sourceCells.length > targetCells.length)
          ? sourceCells.slice(i).map(c => `<div>${c.html}</div>`).join('')
          : sourceCells[i].html
      }

      if (await saveCell(targetRow, targetDisplay, htmlToPaste)) pastedCount++
    }
  }

  return { pastedCount, totalToPaste }
}
