import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { delay: { type: Number, default: 300 } }

  disconnect() {
    window.clearTimeout(this.timeout)
  }

  schedule() {
    window.clearTimeout(this.timeout)
    this.timeout = window.setTimeout(() => this.element.requestSubmit(), this.delayValue)
  }
}
