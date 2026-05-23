import { Controller } from "@hotwired/stimulus"
import { csrfFetch } from 'helpers/fetch_helper'
import { toastError } from 'helpers/toast_helper'

// Handles updating bug fields via PATCH requests with Turbo Stream responses.
// Replaces the global inline `updateBugField()` function from bugs/index.html.slim.
//
// Usage in view:
//   tr data-controller="bug-field" data-bug-field-bug-id-value="123"
//       data-bug-field-project-id-value="1" data-bug-field-task-id-value="5"
//
//   button data-action="click->bug-field#update"
//          data-bug-field-field-param="status" data-bug-field-value-param="done"
export default class extends Controller {
  static values = {
    bugId: Number,
    projectId: Number,
    taskId: Number
  }

  update(event) {
    const field = event.params.field
    const value = event.params.value

    if (field === undefined || value === undefined) return

    const url = `/projects/${this.projectIdValue}/tasks/${this.taskIdValue}/bugs/${this.bugIdValue}`
    const formData = new FormData()
    formData.append(`bug[${field}]`, value)

    csrfFetch(url, {
      method: "PATCH",
      body: formData,
      headers: { "Accept": "text/vnd.turbo-stream.html" }
    })
    .then(response => response.text())
    .then(html => {
      if (typeof Turbo !== "undefined") {
        Turbo.renderStreamMessage(html)
      }
    })
    .catch(() => {
      toastError("Failed to update bug field.")
    })
  }
}
