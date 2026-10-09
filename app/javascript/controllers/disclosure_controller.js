import { Controller } from "@hotwired/stimulus"

// Toggles a panel from a button, keeping aria-expanded in sync.
// Escape closes it and returns focus to the button.
export default class extends Controller {
  static targets = ["button", "panel"]

  disconnect() {
    this.#setOpen(false)
  }

  toggle() {
    this.#setOpen(this.panelTarget.hidden)
  }

  close(event) {
    if (this.panelTarget.hidden) return

    this.#setOpen(false)
    if (event?.type === "keydown") this.buttonTarget.focus()
  }

  closeOnOutsideClick(event) {
    if (!this.element.contains(event.target)) this.#setOpen(false)
  }

  #setOpen(open) {
    this.panelTarget.hidden = !open
    this.buttonTarget.setAttribute("aria-expanded", String(open))
    this.buttonTarget.setAttribute("aria-label", open ? "Close menu" : "Open menu")
  }
}
