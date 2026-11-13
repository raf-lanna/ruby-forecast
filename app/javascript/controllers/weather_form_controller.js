import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["address", "dayOption"];

  connect() {
    this.highlightSelectedDay();
  }

  onInput() {
    this.clearFlash();
  }

  selectDay(event) {
    this.highlightSelectedDay(event.target.value);
  }

  highlightSelectedDay(selectedValue) {
    if (!this.hasDayOptionTarget) return;

    const value = selectedValue ?? this.selectedDayValue;

    this.dayOptionTargets.forEach((option) => {
      option.classList.toggle(
        "zip-form__day-option--selected",
        option.querySelector("input")?.value === value
      );
    });
  }

  validate(event) {
    const address = this.hasAddressTarget ? this.addressTarget.value.trim() : "";

    this.clearFlash();

    if (address.length < 2 || address.length > 200) {
      this.showFlash("alert", "Enter a place, landmark, coordinates, or region (2-200 characters).");
      event.preventDefault();
    }
  }

  showFlash(type, message) {
    const container = this.flashContainer;
    if (!container) return;

    const flash = document.createElement("div");
    flash.classList.add("flash", type);
    flash.setAttribute("role", "alert");
    flash.textContent = message;

    container.appendChild(flash);
  }

  clearFlash() {
    const container = this.flashContainer;
    if (!container) return;

    container.innerHTML = "";
  }

  get flashContainer() {
    return document.querySelector(".flash-messages");
  }

  get selectedDayValue() {
    const selected = this.element.querySelector("input[name='days_from_now']:checked");
    return selected ? selected.value : "0";
  }
}
