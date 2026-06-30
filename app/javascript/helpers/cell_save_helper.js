export function buildSaveRequest(rowElement, field, contentId, value) {
  const model = rowElement.dataset.model || 'test_case'
  const isTestCase = model === 'test_case'
  const { projectId, taskId, testCaseId, bugId } = rowElement.dataset
  const entityId = isTestCase ? testCaseId : bugId
  const entityPath = isTestCase ? 'test_cases' : 'bugs'

  if (contentId && isTestCase) {
    return {
      url: `/test_step_contents/${contentId}`,
      params: { test_step_content: { [field]: value } }
    }
  }

  return {
    url: `/projects/${projectId}/tasks/${taskId}/${entityPath}/${entityId}`,
    params: { [model]: { [field]: value } }
  }
}

export function sanitizePastedHtml(clipboardData) {
  const html = clipboardData.getData('text/html')
  const plain = clipboardData.getData('text/plain')

  if (html) {
    const temp = document.createElement('div')
    temp.innerHTML = html
    temp.querySelectorAll('script, style, meta, link').forEach(el => el.remove())
    return temp.innerHTML
  }

  if (plain) {
    return plain
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/\n/g, '<br>')
  }

  return ''
}
