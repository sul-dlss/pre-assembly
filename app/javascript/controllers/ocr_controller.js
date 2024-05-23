import { Controller } from "@hotwired/stimulus"

export default class extends Controller {

  static targets = ['contentStructure', 'ocrSettings', 'manuallyCorrectedOcrOptions',
    'manuallyCorrectedOcr', 'runOcr', 'ocrLanguages', 'ocrDropdown', 'runOcrDocumentNotes',
    'selectedLanguages', 'languageWarning', 'dropdownContent', 'ocrLanguageWrapper']
  
  static values = { languages: Array }

  connect () {
    this.content_structure_changed();
    this.element.querySelector('form').reset();
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
    return ['simple_image', 'simple_book', 'document']
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
      this.selectedLanguagesTarget.innerHTML = `<div>Selected Languages</div>
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

  changed () {
    if (this.contentStructureTarget && this.ocrAllowed().indexOf(this.contentStructureTarget.value) > -1) {
      this.ocrSettingsTarget.hidden = false;
      this.runOcrTarget.querySelector('legend').innerHTML = this.labelRunOcr();
      this.manuallyCorrectedOcrTarget.querySelector('legend').innerHTML = this.labelManuallyCorrected();
    } else {
      this.ocrSettingsTarget.hidden = true;
    }
  }

  // if the user indicates they want to runn SDR OCR, show any relevant notes/warnings
  run_ocr_changed() {
    const runocr = this.runOcrTarget.querySelector('input[type="radio"]:checked').value == 'true';
    if (runocr)
    {
      const isdocument = this.selected_content_structure().value == 'document';
      this.runOcrDocumentNotesTarget.hidden = !isdocument;
      this.ocrLanguageWrapperTarget.classList.remove('d-none');
    }
    else
    {
      this.runOcrDocumentNotesTarget.hidden = true;
      this.ocrLanguageWrapperTarget.classList.add('d-none');
    }
    Object.values(this.ocrDropdownTarget.children).forEach(child => {
      child.disabled = !runocr;
    })
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

    if (this.selected_content_structure().value == 'document') {
      this.manuallyCorrectedOcrTarget.querySelector('legend').innerHTML = this.labelDocumentsManuallyCorrected()
      this.manuallyCorrectedOcrOptionsTargets[1].labels[0].innerHTML = "No/Don't Know" // the "No" option label for manually corrected document OCR
      this.run_ocr_changed()
    } else {
      this.manuallyCorrectedOcrTarget.querySelector('legend').innerHTML = this.labelImagesManuallyCorrected()
      this.manuallyCorrectedOcrOptionsTargets[1].labels[0].innerHTML = 'No' // the "No" option label for manually corrected image OCR
      this.runOcrDocumentNotesTarget.hidden = true
    }
  }
}
