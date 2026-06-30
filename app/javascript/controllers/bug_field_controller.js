import { Controller } from "@hotwired/stimulus"
import { csrfFetch } from 'helpers/fetch_helper'
import { toastError } from 'helpers/toast_helper'

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
