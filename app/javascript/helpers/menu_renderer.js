export function buildMenuHTML(hasCellCopy, hasRowCopy, groupOptions = {}) {
  const pasteCellClass = hasCellCopy ? "" : "ctx-disabled"
  const pasteRowClass  = hasRowCopy  ? "" : "ctx-disabled"
  const mergeClass     = groupOptions.canMerge ? "" : "ctx-disabled"
  const splitClass     = groupOptions.canSplit  ? "" : "ctx-disabled"

  const dangerItem = groupOptions.isArchived
    ? `<div class="ctx-item ctx-danger" data-action-type="delete">
         <i class="bi bi-trash"></i><span>Delete Row</span>
       </div>`
    : `<div class="ctx-item ctx-danger" data-action-type="archive">
         <i class="bi bi-archive"></i><span>Archive Row</span>
       </div>`

  const groupSection = (groupOptions.canMerge || groupOptions.canSplit) ? `
    <div class="ctx-divider"></div>
    <div class="ctx-item ${mergeClass}" data-action-type="mergeRow">
      <i class="bi bi-link-45deg"></i><span>Merge with above</span>
    </div>
    <div class="ctx-item ${splitClass}" data-action-type="splitRow">
      <i class="bi bi-scissors"></i><span>Split (Unmerge)</span>
    </div>
  ` : ""

  return `
    <div class="ctx-item" data-action-type="editCell">
      <i class="bi bi-pencil"></i><span>Edit Cell</span><kbd>Enter</kbd>
    </div>
    <div class="ctx-divider"></div>
    <div class="ctx-item" data-action-type="copyCell">
      <i class="bi bi-clipboard"></i><span>Copy Cell</span><kbd>Ctrl+C</kbd>
    </div>
    <div class="ctx-item ${pasteCellClass}" data-action-type="pasteCell">
      <i class="bi bi-clipboard-check"></i><span>Paste Cell</span><kbd>Ctrl+V</kbd>
    </div>
    <div class="ctx-divider"></div>
    <div class="ctx-item" data-action-type="copyRow">
      <i class="bi bi-files"></i><span>Copy Row</span>
    </div>
    <div class="ctx-item ${pasteRowClass}" data-action-type="pasteRow">
      <i class="bi bi-file-earmark-check"></i><span>Paste Row</span>
    </div>
    <div class="ctx-item" data-action-type="cloneRow">
      <i class="bi bi-files-alt"></i><span>Clone to another task…</span>
    </div>
    ${groupSection}
    <div class="ctx-divider"></div>
    <div class="ctx-item" data-action-type="setGroupDescription">
      <i class="bi bi-collection"></i><span>Set Group Description</span>
    </div>
    <div class="ctx-divider"></div>
    <div class="ctx-item" data-action-type="clearCell">
      <i class="bi bi-eraser"></i><span>Clear Cell</span><kbd>Del</kbd>
    </div>
    <div class="ctx-item" data-action-type="insertBelow">
      <i class="bi bi-plus-circle"></i><span>Insert Row Below</span>
    </div>
    <div class="ctx-item" data-action-type="history">
      <i class="bi bi-clock-history"></i><span>View History</span>
    </div>
    ${dangerItem}
  `
}

export function positionMenu(menu, clientX, clientY) {
  menu.style.left = `${clientX}px`
  menu.style.top  = `${clientY}px`
  const rect = menu.getBoundingClientRect()
  if (rect.right  > window.innerWidth)  menu.style.left = `${clientX - rect.width}px`
  if (rect.bottom > window.innerHeight) menu.style.top  = `${clientY - rect.height}px`
}

export function getEditableCells(row) {
  return Array.from(row.querySelectorAll("[data-editable-cell-target='display']"))
}

export function findEditableInCell(cell) {
  if (!cell) return null
  return cell.querySelector("[data-editable-cell-target='display']")
}

export function clickFormOrIcon(icon) {
  if (!icon) return
  const form = icon.closest("form")
  if (form) {
    const btn = form.querySelector("button, [type='submit']")
    if (btn) btn.click()
  } else {
    icon.closest("button, a")?.click()
  }
}

export function showSpreadsheetToast(message) {
  document.querySelectorAll(".spreadsheet-toast").forEach(t => t.remove())
  const toast = document.createElement("div")
  toast.className = "spreadsheet-toast"
  toast.textContent = message
  document.body.appendChild(toast)
  requestAnimationFrame(() => toast.classList.add("show"))
  setTimeout(() => {
    toast.classList.remove("show")
    setTimeout(() => toast.remove(), 300)
  }, 2000)
}
