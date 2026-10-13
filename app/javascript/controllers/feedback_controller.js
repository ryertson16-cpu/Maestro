import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "strength",
    "improvement",
    "guidance",
    "reflection",
    "result",
    "output",
    "status",
    "studentSelect"
  ]

  static values = {
    studentName: String,
    activityTitle: String,
    score: String
  }

  selectStudent() {
    if (!this.hasStudentSelectTarget) return

    const option = this.studentSelectTarget.selectedOptions[0]
    this.studentNameValue = option?.dataset?.studentName || ""
    this.scoreValue = option?.dataset?.score || ""

    ;["strength", "improvement", "guidance", "reflection", "output"].forEach((name) => {
      const hasTarget = `has${this.capitalize(name)}Target`
      if (this[hasTarget]) this[`${name}Target`].value = ""
    })

    if (this.hasResultTarget) this.resultTarget.hidden = true
  }

  // Prepara sugestões quando o professor abre o feedback.
  // Não usa preventDefault(), para permitir que o <details> abra normalmente.
  prepare() {
    if (!this.studentNameValue) {
      this.setStatus("Selecione um aluno para preencher as sugestões.", "attention")
      return
    }

    const score = this.parsedScore()

    if (score === null) {
      this.setStatus(
        "Não há uma nota válida registrada para esta atividade. Confira a correção antes de preparar o feedback.",
        "error"
      )
      return
    }

    const suggestions = this.suggestionsFor(score)
    const fields = [
      ["strength", suggestions.strength],
      ["improvement", suggestions.improvement],
      ["guidance", suggestions.guidance],
      ["reflection", suggestions.reflection]
    ]

    let filledCount = 0

    fields.forEach(([targetName, suggestion]) => {
      const hasTarget = `has${this.capitalize(targetName)}Target`

      // Preserva o texto que o professor já digitou.
      if (this[hasTarget] && !this[`${targetName}Target`].value.trim()) {
        this[`${targetName}Target`].value = suggestion
        filledCount += 1
      }
    })

    if (filledCount > 0) {
      this.setStatus("Sugestões preenchidas. Revise o texto.", "success")
    } else {
      this.setStatus("Os campos já têm texto. Nada foi substituído.", "attention")
    }
  }

  // Monta o rascunho para revisão do professor.
  generate(event) {
    event.preventDefault()

    if (!this.studentNameValue) {
      this.setStatus("Selecione um aluno para montar o rascunho.", "attention")
      return
    }

    const score = this.parsedScore()
    const studentName = this.valueOrEmpty("studentName")
    const activityTitle = this.valueOrEmpty("activityTitle")

    const lines = [
      `Olá, ${studentName || "estudante"}.`,
      "",
      `Vamos conversar sobre a atividade "${activityTitle || "atividade selecionada"}".`
    ]

    if (score !== null) {
      lines.push(`Nota registrada: ${this.formatScore(score)} de 10.`)
    } else {
      lines.push("A nota desta atividade ainda não está registrada.")
    }

    const observations = [
      this.observation("O que você fez bem", this.targetValue("strength")),
      this.observation("O que precisa ser revisto", this.targetValue("improvement")),
      this.observation("Próximo passo", this.targetValue("guidance")),
      this.observation("Para refletir", this.targetValue("reflection"))
    ].filter(Boolean)

    if (observations.length > 0) {
      lines.push("", ...observations)
    }

    lines.push("", "Este é um rascunho para revisão do professor.")

    if (this.hasOutputTarget) {
      this.outputTarget.value = lines.join("\n")
    }

    if (this.hasResultTarget) {
      this.resultTarget.hidden = false
    }

    this.setStatus("Rascunho preparado. Revise o texto antes de compartilhar.", "success")
  }

  parsedScore() {
    const rawScore = this.valueOrEmpty("score")
      .trim()
      .replace(",", ".")

    if (!rawScore || !/^(?:\d+\.?\d*|\.\d+)$/.test(rawScore)) {
      return null
    }

    const score = Number(rawScore)

    if (!Number.isFinite(score) || score < 0 || score > 10) {
      return null
    }

    return score
  }

  suggestionsFor(score) {
    // De 0 até menos de 4.
    if (score < 4) {
      return {
        strength:
          "Este resultado nos ajuda a identificar o que você já compreendeu e o que podemos desenvolver a seguir.",
        improvement:
          "É importante retomar os conceitos fundamentais e identificar em quais etapas da atividade surgiu dificuldade.",
        guidance:
          "Revise um exemplo resolvido, refaça as questões com apoio do material e anote suas dúvidas para conversar com o professor.",
        reflection:
          "Qual parte da atividade foi mais difícil e que estratégia você poderia tentar primeiro?"
      }
    }

    // De 4 até menos de 7.
    if (score < 7) {
      return {
        strength:
          "Você demonstrou compreensão de parte do conteúdo e já tem uma base para continuar avançando.",
        improvement:
          "Alguns conceitos e etapas da resolução ainda precisam ser revistos para consolidar a aprendizagem.",
        guidance:
          "Retome as questões em que teve dificuldade, compare seu raciocínio com os exemplos e pratique exercícios semelhantes.",
        reflection:
          "O que você entendeu melhor nesta atividade e qual ponto ainda precisa de mais prática?"
      }
    }

    // De 7 até menos de 10.
    if (score < 10) {
      return {
        strength:
          "Você demonstrou bom domínio do conteúdo e resolveu corretamente grande parte da atividade.",
        improvement:
          "Revise os detalhes das respostas e confira se as justificativas e os cálculos estão completos.",
        guidance:
          "Retome os itens em que perdeu pontos e pratique questões semelhantes para consolidar o que já aprendeu.",
        reflection:
          "Que estratégia ajudou você a resolver a maior parte da atividade e como pode aplicá-la nos próximos desafios?"
      }
    }

    // Nota 10.
    return {
      strength:
        "Você demonstrou domínio completo do conteúdo avaliado nesta atividade.",
      improvement:
        "A nota não indica pontos de correção; você pode aprofundar o tema com novos desafios.",
      guidance:
        "Continue explorando o conteúdo e tente aplicar o que aprendeu em uma situação ou problema diferente.",
      reflection:
        "Qual foi a estratégia mais útil para você nesta atividade e onde mais poderia aplicá-la?"
    }
  }

  valueOrEmpty(name) {
    const hasValue = `has${this.capitalize(name)}Value`

    if (this[hasValue]) {
      return this[`${name}Value`] || ""
    }

    // Alternativa caso o atributo esteja presente no elemento, mas o valor Stimulus não esteja disponível.
    const dataAttribute = `feedback${this.capitalize(name)}Value`
    return this.element.dataset[dataAttribute] || ""
  }

  targetValue(name) {
    const hasTarget = `has${this.capitalize(name)}Target`

    return this[hasTarget]
      ? this[`${name}Target`].value
      : ""
  }

  observation(label, value) {
    const text = value.trim()
    return text ? `${label}: ${text}` : null
  }

  formatScore(value) {
    return value.toLocaleString("pt-BR", {
      minimumFractionDigits: 1,
      maximumFractionDigits: 1
    })
  }

  setStatus(message, kind = "attention") {
    window.MaestroToast?.show({ kind, message })
    if (this.hasStatusTarget) this.statusTarget.textContent = message
  }

  capitalize(value) {
    return value.charAt(0).toUpperCase() + value.slice(1)
  }
}