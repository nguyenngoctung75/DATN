const DISPLAY_SELECTOR = "[data-editable-cell-target='display']"

export function getAllEditableCells(table) {
  if (!table) return []
  return Array.from(table.querySelectorAll(DISPLAY_SELECTOR))
}

export function getEditableCellsInRow(row) {
  if (!row) return []
  return Array.from(row.querySelectorAll(DISPLAY_SELECTOR))
}

export function findHorizontalNeighbor(currentCell, direction) {
  const table = currentCell.closest("table")
  if (!table) return null
  const all = getAllEditableCells(table)
  const idx = all.indexOf(currentCell)
  if (idx === -1) return null
  const next = all[idx + direction]
  return next || null
}

export function findVerticalNeighbor(currentCell, direction) {
  const currentRow = currentCell.closest("tr")
  const table = currentCell.closest("table")
  if (!currentRow || !table) return null

  const rows = Array.from(table.querySelectorAll("tbody tr"))
  const rowIdx = rows.indexOf(currentRow)
  const targetRow = rows[rowIdx + direction]
  if (!targetRow) return null

  const colIdx = getEditableCellsInRow(currentRow).indexOf(currentCell)
  if (colIdx === -1) return null

  const targetCells = getEditableCellsInRow(targetRow)
  return targetCells[colIdx] || null
}
