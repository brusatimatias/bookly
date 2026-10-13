import { Controller } from "@hotwired/stimulus"

// Shows the date fields for whole days blocks and the date and time fields
// otherwise. The hidden ones are disabled so they aren't submitted.
export default class extends Controller {
  static targets = [ "allDay", "days", "times" ]

  connect() {
    this.toggle()
  }

  toggle() {
    const allDay = this.allDayTarget.checked
    this.#show(this.daysTarget, allDay)
    this.#show(this.timesTarget, !allDay)
  }

  #show(group, visible) {
    group.hidden = !visible
    group.querySelectorAll("input").forEach(input => input.disabled = !visible)
  }
}
