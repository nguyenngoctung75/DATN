import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container"]

  connect() {
    this.uniqueIdCounter = this.containerTarget.querySelectorAll('.test-step').length || 0
    if (this.uniqueIdCounter === 0) {
      this.addStep()
    }
  }

  addStep(event) {
    if (event) event.preventDefault()

    const displayStepNumber = this.containerTarget.querySelectorAll('.test-step').length + 1
    const uniqueId = new Date().getTime() + Math.floor(Math.random() * 1000)

    const stepHtml = `
      <div class="card mb-3 test-step" data-unique-id="${uniqueId}">
        <div class="card-header bg-white d-flex justify-content-between align-items-center">
          <h6 class="mb-0 fw-bold step-title">Step ${displayStepNumber}</h6>
          <button type="button" class="btn btn-sm btn-outline-danger" data-action="click->dynamic-form#removeStep">
            <i class="bi bi-trash"></i> Delete
          </button>
        </div>
        <div class="card-body">
          <input type="hidden" class="step-number-input" name="test_case[test_steps_attributes][${uniqueId}][step_number]" value="${displayStepNumber}" />
          <div class="mb-3">
            <label class="form-label fw-semibold">Step Description</label>
            <input type="text" name="test_case[test_steps_attributes][${uniqueId}][description]" class="form-control" placeholder="Step ${displayStepNumber} description" />
          </div>
          <div class="row">
            <div class="col-md-6">
              <label class="form-label fw-semibold">Actions</label>
              <textarea name="test_case[test_steps_attributes][${uniqueId}][test_step_contents_attributes][0][content_value]" class="form-control mb-2" rows="3" placeholder="1. Open login page\n2. Enter email\n3. Enter password"></textarea>
              <input type="hidden" name="test_case[test_steps_attributes][${uniqueId}][test_step_contents_attributes][0][content_type]" value="text" />
              <input type="hidden" name="test_case[test_steps_attributes][${uniqueId}][test_step_contents_attributes][0][content_category]" value="action" />
              <input type="hidden" name="test_case[test_steps_attributes][${uniqueId}][test_step_contents_attributes][0][display_order]" value="0" />
            </div>
            <div class="col-md-6">
              <label class="form-label fw-semibold">Expected Results</label>
              <textarea name="test_case[test_steps_attributes][${uniqueId}][test_step_contents_attributes][1][content_value]" class="form-control mb-2" rows="3" placeholder="Expected results"></textarea>
              <input type="hidden" name="test_case[test_steps_attributes][${uniqueId}][test_step_contents_attributes][1][content_type]" value="text" />
              <input type="hidden" name="test_case[test_steps_attributes][${uniqueId}][test_step_contents_attributes][1][content_category]" value="expectation" />
              <input type="hidden" name="test_case[test_steps_attributes][${uniqueId}][test_step_contents_attributes][1][display_order]" value="0" />
              <label class="form-label fw-semibold mt-2">Evidence URL (Gyazo)</label>
              <input type="url" name="test_case[test_steps_attributes][${uniqueId}][test_step_contents_attributes][2][content_value]" class="form-control" placeholder="https://gyazo.com/..." />
              <input type="hidden" name="test_case[test_steps_attributes][${uniqueId}][test_step_contents_attributes][2][content_type]" value="image" />
              <input type="hidden" name="test_case[test_steps_attributes][${uniqueId}][test_step_contents_attributes][2][content_category]" value="expectation" />
              <input type="hidden" name="test_case[test_steps_attributes][${uniqueId}][test_step_contents_attributes][2][display_order]" value="1" />
            </div>
          </div>
        </div>
      </div>
    `

    this.containerTarget.insertAdjacentHTML('beforeend', stepHtml)
    this.renumberSteps()
  }

  removeStep(event) {
    if (event) event.preventDefault()
    const stepCard = event.target.closest('.test-step')
    stepCard.remove()
    this.renumberSteps()
  }

  renumberSteps() {
    const steps = this.containerTarget.querySelectorAll('.test-step')
    steps.forEach((step, index) => {
      const newNumber = index + 1
      const title = step.querySelector('.step-title')
      if (title) title.textContent = `Step ${newNumber}`

      const stepNumberInput = step.querySelector('.step-number-input')
      if (stepNumberInput) stepNumberInput.value = newNumber
    })
  }
}
