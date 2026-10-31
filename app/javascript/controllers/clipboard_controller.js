import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["source"]
  static values = { copied: { type: String, default: "Recado copiado" } }

  async copy(event) {
    event.preventDefault()

    const button = event.currentTarget
    const original = button.textContent
    const text = this.sourceTarget.value

    try {
      await navigator.clipboard.writeText(text)
      button.textContent = this.copiedValue
      window.MaestroToast?.show({ kind: "success", message: this.copiedValue })
    } catch {
      this.sourceTarget.focus()
      this.sourceTarget.select()
      button.textContent = "Selecione o texto e copie"
    }

    window.setTimeout(() => {
      button.textContent = original
    }, 1800)
  }
}
