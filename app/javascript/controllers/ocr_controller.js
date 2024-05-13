import { Controller } from "@hotwired/stimulus"

export default class extends Controller {

  static targets = ['contentStructure', 'ocrSettings',
    'manuallyCorrectedOcr', 'runOcr', 'manuallyCorrectedOcrOptions', 'runOcrOptions', 'runOcrDocumentNotes']

  connect () {
    this.content_structure_changed();
  }

  selected_content_structure() {
    return this.contentStructureTarget.options[this.contentStructureTarget.selectedIndex]
  }

  labelImagesManuallyCorrected() {
    return `Do your images have pre-existing OCR that has been manually reviewed/corrected for accessibility?`
  }

  labelDocumentsManuallyCorrected() {
    return `Have you manually reviewed/corrected your document(s) for WCAG/PDFUA compliance?`
  }

  labelRunOcr() {
    return `Would you like to run SDR/ABBYY OCR on your ${this.selected_content_structure().label}(s)?`
  }

  // list of content structures that are allowed to run OCR
  ocrAllowed() {
    return ['simple_image', 'document']
  }

  // if the user indicates they are providing OCR and have reviewed it, hide the option to run SDR OCR
  manually_corrected_ocr_changed() {
    if (this.manuallyCorrectedOcrTarget.querySelector('input[type="radio"]:checked').value == 'true')
    {
      this.runOcrTarget.hidden = true
    }
    else
    {
      this.runOcrTarget.hidden = false
    }
  }

  // if the user indicates they want to runn SDR OCR, show any relevant notes/warnings
  run_ocr_changed() {
    if (this.runOcrTarget.querySelector('input[type="radio"]:checked').value == 'true' && this.selected_content_structure().value == 'document')
    {
      this.runOcrDocumentNotesTarget.hidden = false
    }
    else
    {
      this.runOcrDocumentNotesTarget.hidden = true
    }
  }

  content_structure_changed () {
    // Hide the OCR settings if the selected content structure is not in the list of allowed content structures
    if (this.ocrAllowed().indexOf(this.contentStructureTarget.value) < 0) {
      this.ocrSettingsTarget.hidden = true
      return
    }

    // Show the OCR settings if the selected content structure is in the list of allowed content structures
    this.ocrSettingsTarget.hidden = false

    // Set the OCR settings label
    this.runOcrTarget.querySelector('legend').innerHTML = this.labelRunOcr()

    // Set specific OCR labels/options based on the content structure

    if (this.selected_content_structure().value == 'simple_image') {
      this.manuallyCorrectedOcrTarget.querySelector('legend').innerHTML = this.labelImagesManuallyCorrected()
      this.manuallyCorrectedOcrOptionsTargets[1].labels[0].innerHTML = 'No' // the "No" option label for manually corrected image OCR
    }

    if (this.selected_content_structure().value == 'document') {
      this.manuallyCorrectedOcrTarget.querySelector('legend').innerHTML = this.labelDocumentsManuallyCorrected()
      this.manuallyCorrectedOcrOptionsTargets[1].labels[0].innerHTML = "No/Don't Know" // the "No" option label for manually corrected document OCR
    }
  }
}
