import { Controller } from "@hotwired/stimulus"

// Previews a business's brand while it's being edited: the color picker and
// the hex field follow each other (an empty or partial hex shows the default
// color), and the sample takes the color and the chosen logo.
export default class extends Controller {
  static targets = ["picker", "hex", "button", "text", "logo", "logoInput", "removeLogo"]
  static values = { default: String }

  connect() {
    this.update()
    this.showLogo()
  }

  disconnect() {
    this.revokeLogoUrl()
  }

  pick() {
    this.hexTarget.value = this.pickerTarget.value
    this.update()
  }

  type() {
    this.update()
  }

  reset() {
    this.hexTarget.value = ""
    this.update()
  }

  update() {
    const hex = this.hexTarget.value.trim().toLowerCase()
    const color = /^#[0-9a-f]{6}$/.test(hex) ? hex : this.defaultValue
    this.pickerTarget.value = color
    this.buttonTarget.style.backgroundColor = color
    this.textTarget.style.color = color
  }

  // The new file when one is chosen, nothing when the saved one is being
  // removed, the saved one otherwise.
  showLogo() {
    this.revokeLogoUrl()
    const file = this.logoInputTarget.files[0]
    const removing = this.hasRemoveLogoTarget && this.removeLogoTarget.checked
    let url = this.logoTarget.dataset.savedUrl
    if (file) url = this.logoUrl = URL.createObjectURL(file)
    else if (removing) url = null

    this.logoTarget.classList.toggle("hidden", !url)
    if (url) this.logoTarget.src = url
  }

  revokeLogoUrl() {
    if (this.logoUrl) URL.revokeObjectURL(this.logoUrl)
    this.logoUrl = null
  }
}
