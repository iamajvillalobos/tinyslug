import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button"]
  static values = { text: String }

  async copy() {
    await navigator.clipboard.writeText(this.textValue)
    const original = this.buttonTarget.textContent
    this.buttonTarget.textContent = "Copied"
    window.setTimeout(() => { this.buttonTarget.textContent = original }, 1600)
  }
}
