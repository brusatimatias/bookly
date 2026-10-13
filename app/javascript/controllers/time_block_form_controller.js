import { Controller } from "@hotwired/stimulus"

// Shows the date fields for whole days blocks and the date and time fields
// otherwise. The hidden ones are disabled so they aren't submitted. Switching
// to whole days keeps the days already picked with times.
export default class extends Controller {
  static targets = [ "allDay", "days", "times", "startDate", "endDate", "startsAt", "endsAt" ]

  connect() {
    this.#show()
  }

  toggle() {
    if (this.allDayTarget.checked) {
      this.#fillDate(this.startDateTarget, this.startsAtTarget)
      this.#fillDate(this.endDateTarget, this.endsAtTarget)
    }
    this.#show()
  }

  #show() {
    const allDay = this.allDayTarget.checked
    this.#showGroup(this.daysTarget, allDay)
    this.#showGroup(this.timesTarget, !allDay)
  }

  #showGroup(group, visible) {
    group.hidden = !visible
    group.querySelectorAll("input").forEach(input => input.disabled = !visible)
  }

  // "2026-10-15T16:00" -> "2026-10-15", unless a day was already picked.
  #fillDate(dateInput, dateTimeInput) {
    if (!dateInput.value && dateTimeInput.value) dateInput.value = dateTimeInput.value.slice(0, 10)
  }
}
