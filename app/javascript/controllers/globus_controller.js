import { Controller } from "@hotwired/stimulus"

export default class extends Controller {

  static targets = ['requestGlobusLink', 'stagingLocation']

  async createDestination() {
    this.setRequesting()

    const response = await fetch('/globus', {method: 'post'})

    if (response.status == 201) {
      const dest = await response.json()
      this.setFinishedRequest(dest)
      this.setDestination(dest)
    } else if (response.status == 400) {
      const resp = await response.json()
      this.setRequestError(resp.error)
    } else {
      this.setRequestError('Unexpected Globus Error!')
    }
  }

  setDestination(dest) {
    // update the Staging location with the Globus URL
    this.stagingLocationTarget.value = dest.url

    // open a new tab with the Globus Viewer URL in it
    window.open(dest.url)
  }

  setRequesting() {
    const button = this.requestGlobusLinkTarget
    button.innerText = 'Requesting Link...'
    button.disabled = true
  }

  setFinishedRequest(dest) {
    const link = document.createElement('a')
    link.href = dest.url
    link.text = 'Your Globus Link'
    this.requestGlobusLinkTarget.replaceWith(link)
  }

  setRequestError(msg) {
    const span = document.createElement('span')
    span.id = 'globus-error'
    span.classList.add('text-danger')
    span.innerText = msg
    this.requestGlobusLinkTarget.replaceWith(span)
  }
}
