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

const PROMPT_COMMANDS = [
  ["bold", "N"],
  ["italic", "I"],
  ["underline", "S"],
  ["strikeThrough", "T"],
  ["subscript", "X₂"],
  ["superscript", "X²"],
  ["insertUnorderedList", "•"],
  ["insertOrderedList", "1."],
  ["undo", "↺"],
  ["redo", "↻"]
]

function mountPromptEditor(source) {
  if (source.dataset.promptReady === "1") return
  source.dataset.promptReady = "1"

  const editor = document.createElement("div")
  editor.className = "prompt-editor"
  const toolbar = document.createElement("div")
  toolbar.className = "prompt-toolbar"
  toolbar.setAttribute("role", "toolbar")
  PROMPT_COMMANDS.forEach(([command, label]) => {
    const button = document.createElement("button")
    button.type = "button"
    button.className = "prompt-tool"
    button.dataset.command = command
    button.textContent = label
    button.title = command
    button.addEventListener("mousedown", (event) => event.preventDefault())
    button.addEventListener("click", () => {
      surface.focus()
      document.execCommand(command, false, null)
    })
    toolbar.append(button)
  })

  const surface = document.createElement("div")
  surface.className = "prompt-surface"
  surface.contentEditable = "true"
  surface.setAttribute("role", "textbox")
  surface.setAttribute("aria-multiline", "true")
  if (/<\s*\/?\s*(?:b|strong|i|em|u|s|sub|sup|br|p|div|ul|ol|li)\b/i.test(source.value)) {
    surface.innerHTML = source.value
  } else {
    surface.innerText = source.value
  }

  editor.append(toolbar, surface)
  source.classList.add("visually-hidden")
  source.before(editor)

  const form = source.closest("form")
  form?.addEventListener("submit", () => {
    const formatted = surface.querySelector("b, strong, i, em, u, s, sub, sup, ul, ol")
    source.value = formatted ? surface.innerHTML : surface.innerText
  })
}

document.addEventListener("turbo:load", () => {
  document.querySelectorAll("[data-question-form]").forEach(syncQuestionKind)
  document.querySelectorAll("[data-prompt-source]").forEach(mountPromptEditor)
})
