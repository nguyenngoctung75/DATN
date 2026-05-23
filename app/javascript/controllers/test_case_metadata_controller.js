import { Controller } from "@hotwired/stimulus"
import { csrfFetch } from 'helpers/fetch_helper'
import { toastError } from 'helpers/toast_helper'

export default class extends Controller {
  update(event) {
    event.preventDefault()
    const { value, field, testCaseId, projectId, taskId } = event.currentTarget.dataset
    const url = `/projects/${projectId}/tasks/${taskId}/test_cases/${testCaseId}`
    
    const formData = new FormData()
    formData.append(`test_case[${field}]`, value)
    
    csrfFetch(url, {
      method: "PATCH",
      body: formData,
      headers: { "Accept": "text/vnd.turbo-stream.html" }
    })
    .then(response => response.text())
    .then(html => {
      Turbo.renderStreamMessage(html)
    })
    .catch(() => {
      toastError("Failed to update test case. Please try again.")
    })
  }
}
