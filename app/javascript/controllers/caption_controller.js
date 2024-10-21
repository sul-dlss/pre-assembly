import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['contentStructure', 'ocrSettings', 'ocrAvailable', 'sttSettings', 'sttAvailable', 'runStt',
    'manuallyCorrectedOcr', 'manuallyCorrectedStt', 'runOcr', 'ocrLanguages', 'ocrDropdown', 'runOcrDocumentNotes',
    'runOcrImageNotes', 'runSttNotes', 'selectedLanguages', 'languageWarning', 'dropdownContent', 'ocrLanguageWrapper']

  static values = { languages: Array }

  connect () {
    this.contentStructureChanged()
    this.element.querySelector('form').reset()
  }

  ocrAvailable () {
    return this.ocrContentTypes().indexOf(this.contentStructureTarget.value) >= 0 && this.ocrEnabled()
  }

  sttAvailable () {
    return this.sttContentTypes().indexOf(this.contentStructureTarget.value) >= 0 && this.sttEnabled()
  }

  // list of content structures that are allowed to run OCR
  ocrContentTypes () {
    return ['simple_image', 'simple_book', 'document']
  }

  // list of content structures that are allowed to run speech to text
  sttContentTypes () {
    return ['media']
  }

  ocrEnabled () {
    return this.data.get('ocr-enabled') === 'true'
  }

  sttEnabled () {
    return this.data.get('stt-enabled') === 'true'
  }

  selectedContentStructure () {
    return this.contentStructureTarget.options[this.contentStructureTarget.selectedIndex]
  }

  isDocument () {
    return this.selectedContentStructure().value === 'document'
  }

  labelImagesManuallyCorrected () {
    return 'Do the OCR files comply with accessibility standards? More info: <a target=_blank href="https://blog.adobe.com/en/publish/2016/03/08/correcting-ocr-errors">Correcting OCR</a>.'
  }

  labelDocumentsManuallyCorrected () {
    return 'Do the PDF documents comply with accessibility standards? More info: <a target=_blank href="https://uit.stanford.edu/accessibility/guides/pdf">PDF Accessibility</a>.'
  }

  labelRunOcr () {
    return `Do you want to auto-generate OCR files for the ${this.ocrFileTypeLabel()}?`
  }

  ocrFileTypeLabel () {
    return this.isDocument() ? 'PDF documents' : 'images'
  }

  contentStructureChanged () {
    // Hide the OCR and speech to text settings by default; we will show them if the content structure allows them to
    this.ocrSettingsTarget.hidden = true
    this.sttSettingsTarget.hidden = true

    if (this.ocrAvailable()) {
      this.showOcrControls()
    }

    if (this.sttAvailable()) {
      this.showSttControls()
    }
  }

  // Show the OCR settings and controls
  showOcrControls () {
    this.ocrSettingsTarget.hidden = false

    // Set the OCR settings label
    this.runOcrTarget.querySelector('legend').innerHTML = this.labelRunOcr()

    // Set specific OCR labels/options based on the content structure
    if (this.isDocument()) { // documents have different labels and show different questions
      this.manuallyCorrectedOcrTarget.querySelector('legend').innerHTML = this.labelDocumentsManuallyCorrected()
      this.manuallyCorrectedOcrTarget.hidden = false
      this.ocrAvailableTarget.hidden = true
      this.manuallyCorrectedOcrChanged()
    } else { // images and books have the same labels and show the same questions (different from documents)
      this.manuallyCorrectedOcrTarget.querySelector('legend').innerHTML = this.labelImagesManuallyCorrected()
      this.manuallyCorrectedOcrTarget.hidden = true
      this.ocrAvailableTarget.hidden = false
      this.ocrAvailableChanged()
    }

    // update notes/warnings and language selector based on the run OCR option
    this.runOcrChanged()
  }

  // Show the Speech to text settings and controls
  showSttControls () {
    this.sttSettingsTarget.hidden = false
  }

  // if the user indicates they have speech to text available, show/hide the manually corrected and run stt options (for media)
  sttAvailableChanged () {
    const sttAvailable = this.sttAvailableTarget.querySelector('input[type="radio"]:checked').value === 'true'
    this.manuallyCorrectedSttTarget.hidden = !sttAvailable
    this.runSttTarget.hidden = sttAvailable
    this.runSttChanged()
  }

  // if the user indicates they want to run SDR speech to text, show any relevant notes/warnings
  runSttChanged () {
    const runstt = this.runSttTarget.querySelector('input[type="radio"]:checked').value === 'true'
    this.runSttNotesTarget.hidden = !runstt
  }

  // if the user indicates they have ocr available, show/hide the manually corrected and run OCR option (for images/books)
  ocrAvailableChanged () {
    const ocrAvailable = this.ocrAvailableTarget.querySelector('input[type="radio"]:checked').value === 'true'
    this.manuallyCorrectedOcrTarget.hidden = !ocrAvailable
    this.runOcrTarget.hidden = ocrAvailable
    if (ocrAvailable) {
      this.ocrLanguageWrapperTarget.classList.add('d-none')
    } else {
      this.runOcrChanged()
    }
  }

  // if the user indicates they are providing OCR and have reviewed it, show/hide the run OCR option (for documents) and set the OCR available option
  manuallyCorrectedOcrChanged () {
    if (!this.isDocument()) return

    const manuallyCorrectedOcr = this.manuallyCorrectedOcrTarget.querySelector('input[type="radio"]:checked').value === 'true'
    this.ocrAvailableTarget.querySelector(`input[type=radio][value="${manuallyCorrectedOcr}"]`).checked = true
    this.runOcrTarget.hidden = manuallyCorrectedOcr
  }

  // if the user indicates they want to run SDR OCR, show any relevant notes/warnings and language selector
  runOcrChanged () {
    // hide any notes to start, we will show as needed if OCR is selected
    this.runOcrDocumentNotesTarget.hidden = true
    this.runOcrImageNotesTarget.hidden = true

    const runocr = this.runOcrTarget.querySelector('input[type="radio"]:checked').value === 'true'
    if (runocr) {
      this.runOcrDocumentNotesTarget.hidden = !this.isDocument()
      this.runOcrImageNotesTarget.hidden = this.isDocument()
      this.ocrLanguageWrapperTarget.classList.remove('d-none')
    } else {
      this.ocrLanguageWrapperTarget.classList.add('d-none')
    }
    Object.values(this.ocrDropdownTarget.children).forEach(child => {
      child.disabled = !runocr
    })
  }

  languageDropdown (event) {
    const ishidden = Array.from(this.dropdownContentTarget.classList).includes('d-none')
    this.dropdownContentTarget.classList.toggle('d-none')
    this.ocrDropdownTarget.querySelector('#caret').innerHTML = `<i class="fa-solid fa-caret-${ishidden ? 'up' : 'down'}">`
    event.preventDefault()
  }

  clickOutside (event) {
    const isshown = !Array.from(this.dropdownContentTarget.classList).includes('d-none')
    const incontainer = this.ocrLanguageWrapperTarget.contains(event.target)
    const inselectedlangs = event.target.classList.contains('pill-close')
    if (!incontainer && !inselectedlangs && isshown) {
      this.languageDropdown(event)
    }
  }

  languageUpdate (event) {
    const target = event.target ? event.target : event
    if (target.checked) {
      this.languagesValue = this.languagesValue.concat([target.dataset])
    } else {
      this.languagesValue = this.languagesValue.filter(lang => lang.ocrValue !== target.value)
    }
  }

  languagesValueChanged () {
    if (this.languagesValue.length === 0) {
      this.selectedLanguagesTarget.classList.add('d-none')
    } else {
      this.selectedLanguagesTarget.classList.remove('d-none')
      this.selectedLanguagesTarget.innerHTML = `<div>Selected language(s)</div>
                                                <ul class="list-unstyled border rounded mb-3 p-1 bg-white">${this.renderLanguagePills()}</ul>`
    }

    if (this.languagesValue.length > 8) {
      this.languageWarningTarget.classList.remove('d-none')
    } else {
      this.languageWarningTarget.classList.add('d-none')
    }
  }

  search (event) {
    const searchterm = event.target.value.replace(/[^\w\s]/gi, '').toLowerCase()
    this.dropdownContentTarget.classList.remove('d-none')
    this.ocrLanguagesTargets.forEach(target => {
      const compareterm = target.dataset.ocrLabel.replace(/[^\w\s]/gi, '').toLowerCase()
      if (compareterm.includes(searchterm)) {
        target.parentElement.classList.remove('d-none')
      } else {
        target.parentElement.classList.add('d-none')
      }
    })
  }

  deselect (event) {
    event.preventDefault()

    const target = this.ocrLanguagesTargets.find((language) => language.dataset.ocrValue === event.target.id)
    if (target) target.checked = false
    this.languageUpdate(target)
  }

  renderLanguagePills () {
    return this.languagesValue.map((language) => {
      return `
        <li class="d-inline-flex gap-2 align-items-center my-2">
          <span class="bg-light rounded-pill border language-pill">
            <span class="language-label">
              ${language.ocrLabel}
            </span>
            <button data-action="${this.identifier}#deselect" id="${language.ocrValue}" type="button" class="btn-close py-0 pill-close" aria-label="Remove ${language.ocrLabel}"></button>
          </span>
        </li>
      `
    }).join('')
  }
}
