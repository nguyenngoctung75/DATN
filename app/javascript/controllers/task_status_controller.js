import { Controller } from "@hotwired/stimulus"
import { csrfFetch } from "helpers/fetch_helper"
import { toastError } from "helpers/toast_helper"

export default class extends Controller {
  change(event) {
    event.preventDefault()
    const newStatus = event.currentTarget.dataset.taskStatusValue
    const url = event.currentTarget.dataset.taskStatusUrlValue

    csrfFetch(url, {
      method: "PATCH",
      body: JSON.stringify({ task: { status: newStatus } })
    })
    .then(response => {
      if (response.ok) {
        window.location.reload()
      } else {
        toastError("Failed to update status. Please try again.")
      }
    })
    .catch(() => {
      toastError("An error occurred while updating the status.")
    })
  }
}
