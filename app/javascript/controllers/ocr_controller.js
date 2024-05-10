import { Controller } from "@hotwired/stimulus"

export default class extends Controller {

  static targets = ['contentStructure', 'ocrSettings',
    'manuallyCorrectedOcr', 'runOcr']

  connect () {
    this.changed();
  }

  selected (){
    return this.contentStructureTarget.options[this.contentStructureTarget.selectedIndex].label
  }

  labelManuallyCorrected() {
    return `Do the ${this.selected()}(s) have pre-existing OCR that has been manually reviewed/corrected for accessibility?`
  }

  labelRunOcr() {
    return `Would you like to run SDR/ABBYY OCR on your ${this.selected()}(s)?`
  }

  ocrAllowed() {
    return ['simple_image', 'document']
  }
  changed () {
    if (this.ocrAllowed().indexOf(this.contentStructureTarget.value) > -1) {
      this.ocrSettingsTarget.hidden = false;
      this.runOcrTarget.querySelector('legend').innerHTML = this.labelRunOcr();
      this.manuallyCorrectedOcrTarget.querySelector('legend').innerHTML = this.labelManuallyCorrected();
    } else {
      this.ocrSettingsTarget.hidden = true;
    }
  }

}
