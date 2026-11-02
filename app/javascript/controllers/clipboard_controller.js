import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["source"]
  static values = {
    copied: { type: String, default: "Recado copiado" },
    url: String
  }

  async copy(event) {
    event.preventDefault()

    const button = event.currentTarget
    const original = button.textContent
    let text = ""

    try {
      if (this.hasUrlValue && this.urlValue) {
        const response = await fetch(this.urlValue, {
          headers: { Accept: "application/json" },
          credentials: "same-origin"
        })
        if (!response.ok) throw new Error("pack")
        text = await response.text()
      } else {
        text = this.sourceTarget.value
      }

      await navigator.clipboard.writeText(text)
      button.textContent = this.copiedValue
      window.MaestroToast?.show({ kind: "success", message: this.copiedValue })
    } catch {
      if (this.hasSourceTarget) {
        this.sourceTarget.focus()
        this.sourceTarget.select()
        button.textContent = "Selecione o texto e copie"
      } else {
        button.textContent = "Não deu para copiar"
      }
    }

    window.setTimeout(() => {
      button.textContent = original
    }, 1800)
  }
}
