import { Controller } from "@hotwired/stimulus"
import { csrfFetch } from 'helpers/fetch_helper'

export default class extends Controller {
  update(event) {
    event.preventDefault()
    const { status, device, testCaseId, projectId, taskId } = event.currentTarget.dataset
    const url = `/projects/${projectId}/tasks/${taskId}/test_cases/${testCaseId}/test_results`
    
    const formData = new FormData()
    formData.append("test_result[status]", status)
    formData.append("test_result[device]", device)
    
    csrfFetch(url, {
      method: "POST",
      body: formData,
      headers: { "Accept": "text/vnd.turbo-stream.html" }
    })
    .then(response => response.text())
    .then(html => {
      Turbo.renderStreamMessage(html)
    })
  }
}
