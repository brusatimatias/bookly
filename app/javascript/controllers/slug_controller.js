import { Controller } from "@hotwired/stimulus"

// Suggests a business's web address from its name while the address hasn't
// been typed by hand, and previews it.
export default class extends Controller {
  static targets = ["name", "slug", "preview"]

  connect() {
    this.edited = this.slugTarget.value !== "" && this.slugTarget.value !== this.parameterize(this.nameTarget.value)
    this.preview()
  }

  suggest() {
    if (!this.edited) this.slugTarget.value = this.parameterize(this.nameTarget.value)
    this.preview()
  }

  edit() {
    this.edited = this.slugTarget.value !== ""
    if (!this.edited) this.suggest()
    this.preview()
  }

  preview() {
    this.previewTarget.textContent = this.slugTarget.value
  }

  // "Barbería Centro" -> "barberia-centro", like Rails' parameterize.
  parameterize(value) {
    return value.normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase()
      .replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "")
  }
}
