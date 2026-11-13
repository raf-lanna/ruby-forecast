import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { timeout: { type: Number, default: 6000 } }

  connect() {
    this.remaining = this.timeoutValue
    this.startTimer()
  }

  disconnect() {
    this.clearTimer()
  }

  pause() {
    if (this.startedAt == null) return

    this.remaining -= Date.now() - this.startedAt
    this.clearTimer()
  }

  resume() {
    if (this.element.classList.contains("flash--leaving")) return

    if (this.remaining <= 0) {
      this.dismiss()
      return
    }

    this.startTimer()
  }

  dismiss() {
    if (this.element.classList.contains("flash--leaving")) return

    this.clearTimer()
    this.element.classList.add("flash--leaving")

    const remove = () => {
      if (this.element.isConnected) this.element.remove()
    }

    this.element.addEventListener("transitionend", remove, { once: true })
    window.setTimeout(remove, 400)
  }

  startTimer() {
    this.startedAt = Date.now()
    this.timer = window.setTimeout(() => this.dismiss(), Math.max(this.remaining, 0))
  }

  clearTimer() {
    if (this.timer) window.clearTimeout(this.timer)
    this.timer = null
    this.startedAt = null
  }
}
