import { Controller } from "@hotwired/stimulus"

export default class extends Controller {

  static targets = ['requestGlobusLink', 'stagingLocation']

  async createDestination() {
    this.setRequesting()

    const response = await fetch('/globus', {method: 'post'})

    if (response.ok) {
      const dest = await response.json()
      this.setFinishedRequest(dest)
      this.setDestination(dest)
    } else {
      console.log('Unable to create Globus Destination:', response)
      throw new Error('Unable to create Globus Destination')
    }
  }

  setDestination(dest) {
    // update the Staging location with the Globus URL
    this.stagingLocationTarget.value = dest.url

    // open a new tab witht the Globus Viewer URL in it
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
}
