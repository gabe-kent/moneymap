import { Controller } from "@hotwired/stimulus"

// Submits the surrounding form as soon as a control changes, so filter
// dropdowns apply without a separate "Apply" button.
export default class extends Controller {
  submit() {
    this.element.form.requestSubmit()
  }
}
