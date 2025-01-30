import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static values = {
    clip: String
  }

  connect () {
    this.running = false
  }

  copy (event) {
    if (this.running) return
    this.running = true

    const el = event.target

    const spanEl = document.createElement('span')
    spanEl.classList.add('badge', 'bg-primary', 'ms-1', 'z-2', 'position-absolute')
    spanEl.innerHTML = 'Copied'

    el.after(spanEl)

    navigator.clipboard.writeText(this.clipValue)
    event.preventDefault()

    setTimeout(function () { spanEl.remove(); this.running = false }, 1500)
  }
}
