import { Controller } from "@hotwired/stimulus"
import { csrfFetch } from "helpers/fetch_helper"
import { toastError } from "helpers/toast_helper"

export default class extends Controller {
  change(event) {
    event.preventDefault()
    const newPhase = event.currentTarget.dataset.taskPhaseValue
    const url = event.currentTarget.dataset.taskPhaseUrlValue

    csrfFetch(url, {
      method: "PATCH",
      body: JSON.stringify({ task: { test_phase: newPhase } })
    })
    .then(response => {
      if (response.ok) {
        window.location.reload()
      } else {
        toastError("Failed to update test phase. Please try again.")
      }
    })
    .catch(() => {
      toastError("An error occurred while updating the test phase.")
    })
  }
}
