import { Controller } from "@hotwired/stimulus"

export default class extends Controller {

  static targets = ['contentStructure', 'ocrSettings', 'manuallyCorrectedOcrOptions', 'ocrAvailable',
    'ocrAvailableOptions', 'manuallyCorrectedOcr', 'runOcr', 'ocrLanguages', 'ocrDropdown', 'runOcrDocumentNotes',
    'runOcrImageNotes', 'selectedLanguages', 'languageWarning', 'dropdownContent', 'ocrLanguageWrapper',
    'processingConfiguration']

  static values = { languages: Array }

  connect () {
    this.contentStructureChanged();
    this.element.querySelector('form').reset();
  }

  // list of content structures that are allowed to run OCR
  ocrAllowed() {
    return ['simple_image', 'simple_book', 'document']
  }

  groupByFilenameTypes()
  {
    return ['simple_image', 'simple_book', 'maps']
  }

  selectedContentStructure() {
    return this.contentStructureTarget.options[this.contentStructureTarget.selectedIndex]
  }

  isDocument() {
    return this.selectedContentStructure().value == 'document'
  }

  labelImagesManuallyCorrected() {
    return `Have the OCR files been corrected to comply with accessibility standards?  More info: <a target=_blank href="https://blog.adobe.com/en/publish/2016/03/08/correcting-ocr-errors">Correcting OCR</a>.`
  }

  labelDocumentsManuallyCorrected() {
    return `Have the PDF documents been corrected to comply with accessibility standards?  More info: <a target=_blank href="https://uit.stanford.edu/accessibility/guides/pdf">PDF Accessibility</a>.`
  }

  labelRunOcr() {
    return `Would you like to auto-generate OCR files for the ${this.selectedContentStructure().label.toLowerCase()}(s)?`
  }

  contentStructureChanged () {
    // set the processing configuration based on the content structure
    this.setProcessingConfiguration()

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

  // if the user indicates they have ocr available (show/hide the manually corrected and run OCR option (for images/books)
  ocrAvailableChanged() {
    const ocr_available = this.ocrAvailableTarget.querySelector('input[type="radio"]:checked').value == 'true'
    this.manuallyCorrectedOcrTarget.hidden = !ocr_available
    this.runOcrTarget.hidden = ocr_available
  }

  // if the user indicates they are providing OCR and have reviewed it, show/hide the run OCR option (for documents)
  manuallyCorrectedOcrChanged() {
    if (!this.isDocument()) return

    this.runOcrTarget.hidden = this.manuallyCorrectedOcrTarget.querySelector('input[type="radio"]:checked').value == 'true'
  }

  // if the user indicates they want to run SDR OCR, show any relevant notes/warnings and language selector
  runOcrChanged() {
    // hide any notes to start, we will show as needed if OCR is selected
    this.runOcrDocumentNotesTarget.hidden = true
    this.runOcrImageNotesTarget.hidden = true

    const runocr = this.runOcrTarget.querySelector('input[type="radio"]:checked').value == 'true';
    if (runocr)
    {
      this.runOcrDocumentNotesTarget.hidden = !this.isDocument();
      this.runOcrImageNotesTarget.hidden = this.isDocument();
      this.ocrLanguageWrapperTarget.classList.remove('d-none');
    }
    else
    {
      this.ocrLanguageWrapperTarget.classList.add('d-none');
    }
    Object.values(this.ocrDropdownTarget.children).forEach(child => {
      child.disabled = !runocr;
    })
  }

  // set the default processing configuration based on the content structure
  setProcessingConfiguration() {
      if (this.groupByFilenameTypes().indexOf(this.selectedContentStructure().value) >= 0) {
        this.processingConfigurationTarget.value = 'filename'
      } else {
        this.processingConfigurationTarget.value = 'default'
      }
  }

  languageDropdown(event) {
    const ishidden = Array.from(this.dropdownContentTarget.classList).includes('d-none');
    this.dropdownContentTarget.classList.toggle('d-none');
    this.ocrDropdownTarget.querySelector('#caret').innerHTML = `<i class="fa-solid fa-caret-${ishidden ? 'up' : 'down'}">`
    event.preventDefault();
  }

  clickOutside(event) {
    const isshown = !Array.from(this.dropdownContentTarget.classList).includes('d-none');
    const incontainer = this.ocrLanguageWrapperTarget.contains(event.target);
    const inselectedlangs = event.target.classList.contains('pill-close');
    if (!incontainer && !inselectedlangs && isshown) {
      this.languageDropdown(event);
    }
  }

  languageUpdate(event) {
    const target = event.target ? event.target : event;
    if (target.checked) {
      this.languagesValue = this.languagesValue.concat([target.dataset]);
    } else {
      this.languagesValue = this.languagesValue.filter(lang => lang.ocrValue != target.value);
    }
  }

  languagesValueChanged() {
    if (this.languagesValue.length == 0) {
      this.selectedLanguagesTarget.classList.add('d-none');
    } else {
      this.selectedLanguagesTarget.classList.remove('d-none');
      this.selectedLanguagesTarget.innerHTML = `<div>Selected Language(s)</div>
                                                <ul class="list-unstyled border rounded mb-3 p-1">${this.renderLanguagePills()}</ul>`;
    }

    if (this.languagesValue.length > 8) {
      this.languageWarningTarget.classList.remove('d-none');
    } else {
      this.languageWarningTarget.classList.add('d-none');
    }
  }

  search(event){
    const searchterm = event.target.value.replace(/[^\w\s]/gi, '').toLowerCase();
    this.dropdownContentTarget.classList.remove('d-none');
    this.ocrLanguagesTargets.forEach(target => {
      const compareterm = target.dataset.ocrLabel.replace(/[^\w\s]/gi, '').toLowerCase();
      if (compareterm.includes(searchterm)) {
        target.parentElement.classList.remove('d-none');
      } else {
        target.parentElement.classList.add('d-none');
      }
    })
  }

  deselect(event) {
    event.preventDefault();

    const target = this.ocrLanguagesTargets.find((language) => language.dataset.ocrValue === event.target.id)
    if (target) target.checked = false;
    this.languageUpdate(target);
  }

  renderLanguagePills() {
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
      `;
    }).join('');
  }
}
