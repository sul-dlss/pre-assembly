import { Controller } from "@hotwired/stimulus"

export default class extends Controller {

  static targets = ['contentStructure', 'ocrSettingsImage', 'ocrSettingsDocument',
    'manuallyCorrectedOcrImage', 'runOcrImage', 'manuallyCorrectedOcrDocument', 'runOcrDocument']

  connect () {
    this.changed()
  }

  changed () {
    this.ocrSettingsImageTarget.hidden = true
    this.ocrSettingsDocumentTarget.hidden = true

    if (this.contentStructureTarget.value == 'simple_image') {
        this.ocrSettingsImageTarget.hidden = false
        this.manuallyCorrectedOcrImageTarget.disabled = false
        this.runOcrImageTarget.disabled = false
        this.manuallyCorrectedOcrDocumentTarget.disabled = true
        this.runOcrDocumentTarget.disabled = true
    }
    else if (this.contentStructureTarget.value == 'document') {
        this.ocrSettingsDocumentTarget.hidden = false
        this.manuallyCorrectedOcrDocumentTarget.disabled = false
        this.runOcrDocumentTarget.disabled = false
        this.manuallyCorrectedOcrImageTarget.disabled = true
        this.runOcrImageTarget.disabled = true
    }
  }

}
