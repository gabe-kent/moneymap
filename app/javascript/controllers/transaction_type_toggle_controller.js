import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["transactionFields", "transferFields"]

  toggle(event) {
    const isTransfer = event.target.value === "transfer"
    this.transactionFieldsTarget.hidden = isTransfer
    this.transferFieldsTarget.hidden = !isTransfer
  }
}
