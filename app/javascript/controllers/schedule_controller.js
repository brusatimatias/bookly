import { Controller } from "@hotwired/stimulus"

// Weekly hours editor: adds and removes the ranges of each day, and copies
// Monday's ranges to the other weekdays. Nothing is saved until the form is
// submitted.
export default class extends Controller {
  static targets = [ "day", "template" ]

  add(event) {
    const range = this.#append(event.target.closest("[data-day]"))
    range.querySelector("[data-field=start]").focus()
  }

  remove(event) {
    const day = event.target.closest("[data-day]")
    event.target.closest("[data-range]").remove()
    this.#refresh(day)
  }

  copyToWeekdays() {
    const times = [ ...this.#day(1).querySelectorAll("[data-range]") ].map(range => [
      range.querySelector("[data-field=start]").value,
      range.querySelector("[data-field=end]").value
    ])

    for (const day of [ 2, 3, 4, 5 ].map(number => this.#day(number))) {
      day.querySelectorAll("[data-range]").forEach(range => range.remove())
      times.forEach(([ start, end ]) => this.#append(day, start, end))
      this.#refresh(day)
    }
  }

  #append(day, start = "", end = "") {
    const range = this.templateTarget.content.firstElementChild.cloneNode(true)
    range.querySelector("[data-field=day]").value = day.dataset.day
    range.querySelector("[data-field=start]").value = start
    range.querySelector("[data-field=end]").value = end
    day.querySelector("[data-ranges]").append(range)
    this.#refresh(day)
    return range
  }

  #day(number) {
    return this.dayTargets.find(day => day.dataset.day === String(number))
  }

  // Shows "doesn't work" on days without ranges.
  #refresh(day) {
    day.querySelector("[data-closed]").hidden = day.querySelector("[data-range]") !== null
  }
}
