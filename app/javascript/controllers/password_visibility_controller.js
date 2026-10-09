import { Controller } from "@hotwired/stimulus"

// Shows or hides a password field's value. The button stays hidden until
// JavaScript connects, so the plain password field still works without it.
export default class extends Controller {
  static targets = ["input", "button", "showIcon", "hideIcon"]

  connect() {
    this.buttonTarget.hidden = false
  }

  disconnect() {
    this.#reveal(false)
  }

  toggle() {
    this.#reveal(this.inputTarget.type === "password")
  }

  #reveal(visible) {
    this.inputTarget.type = visible ? "text" : "password"
    this.buttonTarget.setAttribute("aria-pressed", String(visible))
    this.showIconTarget.hidden = visible
    this.hideIconTarget.hidden = !visible
  }
}
