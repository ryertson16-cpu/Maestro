function syncQuestionKind(root) {
  const kind = root.querySelector("[data-question-kind]")
  const choices = root.querySelector("[data-question-choices]")
  if (!kind || !choices) return

  choices.hidden = kind.value === "discursive"
}

document.addEventListener("change", (event) => {
  if (!event.target.matches("[data-question-kind]")) return
  const root = event.target.closest("[data-question-form]")
  if (root) syncQuestionKind(root)
})

document.addEventListener("turbo:load", () => {
  document.querySelectorAll("[data-question-form]").forEach(syncQuestionKind)
})
