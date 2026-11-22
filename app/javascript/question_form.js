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
  ["bold", "N", "Negrito"],
  ["italic", "I", "Itálico"],
  ["underline", "S", "Sublinhado"],
  ["strikeThrough", "T", "Riscado"],
  ["subscript", "X₂", "Subscrito"],
  ["superscript", "X²", "Sobrescrito"],
  ["insertUnorderedList", "•", "Lista"],
  ["insertOrderedList", "1.", "Lista numerada"],
  ["justifyLeft", "Esq.", "Alinhado à esquerda"],
  ["justifyCenter", "Centro", "Centralizado"],
  ["justifyRight", "Dir.", "Alinhado à direita"],
  ["justifyFull", "Just.", "Justificado"],
  ["undo", "↺", "Desfazer"],
  ["redo", "↻", "Refazer"]
]

const RICH_MARK = /<\s*\/?\s*(?:b|strong|i|em|u|s|strike|sub|sup|br|p|div|ul|ol|li|span|font|table|thead|tbody|tr|td|th|img)\b/i

const TOGGLE_COMMANDS = new Set([
  "bold",
  "italic",
  "underline",
  "strikeThrough",
  "subscript",
  "superscript",
  "insertUnorderedList",
  "insertOrderedList",
  "justifyLeft",
  "justifyCenter",
  "justifyRight",
  "justifyFull"
])

function refreshPromptTools(toolbar) {
  toolbar.querySelectorAll(".prompt-tool[data-command]").forEach((button) => {
    const command = button.dataset.command
    if (!TOGGLE_COMMANDS.has(command)) return
    let active = false
    try {
      active = document.queryCommandState(command)
    } catch (_error) {
      active = false
    }
    button.classList.toggle("is-active", active)
    button.setAttribute("aria-pressed", active ? "true" : "false")
  })
}

function toolButton(command, label, title, surface, toolbar) {
  const button = document.createElement("button")
  button.type = "button"
  button.className = "prompt-tool"
  button.dataset.command = command
  button.textContent = label
  button.title = title
  if (TOGGLE_COMMANDS.has(command)) button.setAttribute("aria-pressed", "false")
  button.addEventListener("mousedown", (event) => event.preventDefault())
  button.addEventListener("click", () => {
    surface.focus()
    document.execCommand(command, false, null)
    surface.dispatchEvent(new Event("input", { bubbles: true }))
    refreshPromptTools(toolbar)
  })
  return button
}

function clampCount(value, fallback, max) {
  const number = Number.parseInt(value, 10)
  if (!Number.isFinite(number)) return fallback
  return Math.min(max, Math.max(1, number))
}

function quadroHtml(rows, columns, header) {
  const cells = []
  for (let row = 0; row < rows; row += 1) {
    const tag = header && row === 0 ? "th" : "td"
    const line = []
    for (let column = 0; column < columns; column += 1) line.push(`<${tag}><br></${tag}>`)
    cells.push(`<tr>${line.join("")}</tr>`)
  }
  return `<table>${cells.join("")}</table>`
}

function quadroTool(surface) {
  const wrap = document.createElement("span")
  wrap.className = "prompt-quadro"
  const toggle = document.createElement("button")
  toggle.type = "button"
  toggle.className = "prompt-tool"
  toggle.textContent = "Quadro"
  toggle.title = "Inserir um quadro com texto"
  toggle.setAttribute("aria-expanded", "false")

  const panel = document.createElement("div")
  panel.className = "prompt-quadro-panel"
  panel.hidden = true
  panel.innerHTML = [
    '<label>Linhas <input class="prompt-quadro-count" type="number" min="1" max="12" value="3" data-quadro-rows></label>',
    '<label>Colunas <input class="prompt-quadro-count" type="number" min="1" max="8" value="3" data-quadro-cols></label>',
    '<label class="prompt-quadro-check"><input type="checkbox" data-quadro-header checked> Primeira linha é o título</label>',
    '<button type="button" class="prompt-tool" data-quadro-insert>Inserir quadro</button>'
  ].join("")

  let savedRange = null
  const rememberSelection = () => {
    const selection = document.getSelection()
    if (!selection?.rangeCount || !surface.contains(selection.anchorNode)) return
    savedRange = selection.getRangeAt(0).cloneRange()
  }
  const restoreSelection = () => {
    surface.focus()
    if (!savedRange) return
    const selection = document.getSelection()
    selection.removeAllRanges()
    selection.addRange(savedRange)
  }

  toggle.addEventListener("mousedown", (event) => {
    event.preventDefault()
    rememberSelection()
  })
  toggle.addEventListener("click", () => {
    panel.hidden = !panel.hidden
    toggle.setAttribute("aria-expanded", panel.hidden ? "false" : "true")
    if (!panel.hidden) panel.querySelector("[data-quadro-rows]")?.focus()
  })
  panel.addEventListener("mousedown", (event) => {
    if (event.target.closest("[data-quadro-insert]")) event.preventDefault()
  })
  panel.querySelector("[data-quadro-insert]").addEventListener("click", () => {
    const rows = clampCount(panel.querySelector("[data-quadro-rows]").value, 3, 12)
    const columns = clampCount(panel.querySelector("[data-quadro-cols]").value, 3, 8)
    const header = panel.querySelector("[data-quadro-header]").checked
    restoreSelection()
    document.execCommand("insertHTML", false, quadroHtml(rows, columns, header))
    surface.dispatchEvent(new Event("input", { bubbles: true }))
    panel.hidden = true
    toggle.setAttribute("aria-expanded", "false")
  })
  document.addEventListener("mousedown", (event) => {
    if (!wrap.contains(event.target)) {
      panel.hidden = true
      toggle.setAttribute("aria-expanded", "false")
    }
  })

  wrap.append(toggle, panel)
  return wrap
}

function mountPromptEditor(source) {
  if (source.dataset.promptReady === "1") return
  source.dataset.promptReady = "1"

  const editor = document.createElement("div")
  editor.className = "prompt-editor"
  const toolbar = document.createElement("div")
  toolbar.className = "prompt-toolbar"
  toolbar.setAttribute("role", "toolbar")

  const surface = document.createElement("div")
  surface.className = "prompt-surface"
  surface.contentEditable = "true"
  surface.setAttribute("role", "textbox")
  surface.setAttribute("aria-multiline", "true")
  if (RICH_MARK.test(source.value)) surface.innerHTML = source.value
  else surface.innerText = source.value

  PROMPT_COMMANDS.forEach(([command, label, title]) => {
    toolbar.append(toolButton(command, label, title, surface, toolbar))
  })

  const color = document.createElement("input")
  color.type = "color"
  color.className = "prompt-tool-color"
  color.title = "Cor"
  color.value = "#1f2937"
  color.addEventListener("input", () => {
    surface.focus()
    document.execCommand("foreColor", false, color.value)
    surface.dispatchEvent(new Event("input", { bubbles: true }))
  })
  toolbar.append(color)

  const size = document.createElement("select")
  size.className = "prompt-tool-size"
  size.title = "Tamanho da letra"
  size.innerHTML = [
    ["", "Tamanho"],
    ["2", "10"],
    ["3", "12"],
    ["4", "14"],
    ["5", "18"],
    ["6", "24"],
    ["7", "32"]
  ].map(([value, label]) => `<option value="${value}">${label}</option>`).join("")
  size.addEventListener("change", () => {
    if (!size.value) return
    surface.focus()
    document.execCommand("fontSize", false, size.value)
    size.value = ""
    surface.dispatchEvent(new Event("input", { bubbles: true }))
  })
  toolbar.append(size)

  toolbar.append(quadroTool(surface))

  const image = document.createElement("button")
  image.type = "button"
  image.className = "prompt-tool"
  image.textContent = "Imagem"
  image.title = "Inserir imagem"
  const file = document.createElement("input")
  file.type = "file"
  file.accept = "image/png,image/jpeg,image/webp,image/gif"
  file.hidden = true
  image.addEventListener("mousedown", (event) => event.preventDefault())
  image.addEventListener("click", () => file.click())
  file.addEventListener("change", () => {
    const chosen = file.files && file.files[0]
    file.value = ""
    if (!chosen) return
    const reader = new FileReader()
    reader.onload = () => {
      const picture = new Image()
      picture.onload = () => {
        const canvas = document.createElement("canvas")
        const scale = Math.min(1, 900 / picture.width)
        canvas.width = Math.max(1, Math.round(picture.width * scale))
        canvas.height = Math.max(1, Math.round(picture.height * scale))
        canvas.getContext("2d").drawImage(picture, 0, 0, canvas.width, canvas.height)
        surface.focus()
        document.execCommand("insertHTML", false, `<img src="${canvas.toDataURL("image/jpeg", 0.82)}" alt="">`)
        surface.dispatchEvent(new Event("input", { bubbles: true }))
      }
      picture.src = reader.result
    }
    reader.readAsDataURL(chosen)
  })
  toolbar.append(image, file)

  editor.append(toolbar, surface)
  source.classList.add("visually-hidden")
  source.before(editor)

  const sync = () => {
    source.value = RICH_MARK.test(surface.innerHTML) ? surface.innerHTML : surface.innerText
  }
  const refresh = () => {
    const selection = document.getSelection()
    if (!selection?.anchorNode || !surface.contains(selection.anchorNode)) return
    refreshPromptTools(toolbar)
  }
  surface.addEventListener("input", sync)
  surface.addEventListener("keyup", refresh)
  surface.addEventListener("mouseup", refresh)
  document.addEventListener("selectionchange", refresh)
  source.closest("form")?.addEventListener("submit", sync)
}

function bootQuestionForm() {
  document.querySelectorAll("[data-question-form]").forEach(syncQuestionKind)
  document.querySelectorAll("[data-prompt-source]").forEach(mountPromptEditor)
}

document.addEventListener("turbo:load", bootQuestionForm)
document.addEventListener("DOMContentLoaded", bootQuestionForm)
if (document.readyState !== "loading") bootQuestionForm()
