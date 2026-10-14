function dialog() {
  return document.querySelector("[data-maestro-quick]")
}

function resultBox() {
  return document.querySelector("[data-maestro-quick-result]")
}

function input() {
  return document.querySelector("[data-maestro-quick-input]")
}

function csrfToken() {
  return document.querySelector("meta[name='csrf-token']")?.getAttribute("content") || ""
}

function reminderIntent() {
  return dialog()?.dataset.reminder === "true"
}

function setReminderIntent(value) {
  const node = dialog()
  if (node) node.dataset.reminder = value ? "true" : "false"
}

function openQuick(opts = {}) {
  const node = dialog()
  const field = input()
  if (!node || !field) return

  if (!node.open) node.showModal()
  setReminderIntent(Boolean(opts.reminder))
  if (opts.reminder) field.placeholder = "Me lembra de… amanhã às 19h"
  field.focus()
}

function closeQuick() {
  const node = dialog()
  if (node?.open) node.close()
}

function escapeHtml(value) {
  return String(value || "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
}

function markUrl() {
  return dialog()?.dataset.markUrl || ""
}

function reminderCardMarkup(card) {
  return `
    <article class="reminder-created-card" data-reminder-id="${escapeHtml(card.id)}">
      <div class="reminder-created-top">
        <img src="${escapeHtml(markUrl())}" alt="" class="maestro-assistant-mark maestro-assistant-mark-sm">
        <span class="section-eyebrow">Lembrete criado</span>
      </div>
      <h3>
        <span class="reminder-dot" aria-hidden="true"></span>
        ${escapeHtml(card.title)}
      </h3>
      <p class="reminder-time">
        ${escapeHtml(card.time_label)}
        <small>${escapeHtml(card.when_label)} ${escapeHtml(card.remain_label)}</small>
      </p>
      <button type="button" class="button button-secondary" data-reminder-undo="${escapeHtml(card.id)}">Desfazer</button>
    </article>
  `
}

function textMarkup(message) {
  return `<article class="maestro-quick-reply">${escapeHtml(message).replace(/\n/g, "<br>")}</article>`
}

function listMarkup(items) {
  if (!items.length) {
    return `<p class="maestro-quick-empty">Nenhum lembrete à frente.</p>`
  }

  const rows = items
    .map(
      (card) => `
        <li>
          <span class="reminder-dot" aria-hidden="true"></span>
          <div>
            <strong>${escapeHtml(card.title)}</strong>
            <span>${escapeHtml(card.weekday_label)}, ${escapeHtml(card.time_label)} · ${escapeHtml(card.remain_label)}</span>
          </div>
        </li>
      `
    )
    .join("")

  return `<ul class="maestro-quick-list">${rows}</ul>`
}

function showResult(html) {
  const box = resultBox()
  if (box) box.innerHTML = html
}

async function postJSON(url, body) {
  const response = await fetch(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Accept: "application/json",
      "X-CSRF-Token": csrfToken()
    },
    body: JSON.stringify(body)
  })
  const data = await response.json().catch(() => ({}))
  return { ok: response.ok, data }
}

async function submitQuick(event) {
  event.preventDefault()
  const node = dialog()
  const field = input()
  if (!node || !field) return

  const body = field.value.trim()
  if (!body) return

  const { data } = await postJSON(node.dataset.createUrl, {
    body,
    reminder: reminderIntent()
  })

  if (data.type === "reminder" && data.reminder) {
    showResult(reminderCardMarkup(data.reminder))
    field.value = ""
    setReminderIntent(false)
    field.placeholder = "Ex.: me lembra da reunião de pais amanhã às 19h"
    return
  }

  if (data.type === "error") {
    showResult(textMarkup(data.message || "Não consegui criar o lembrete."))
    return
  }

  showResult(textMarkup(data.message || "Pronto."))
  field.value = ""
}

async function undoReminder(id) {
  const node = dialog()
  if (!node) return

  await fetch(`${node.dataset.createUrl.replace(/\/$/, "")}/${id}`, {
    method: "DELETE",
    headers: {
      Accept: "application/json",
      "X-CSRF-Token": csrfToken()
    }
  })

  showResult(textMarkup("Lembrete desfeito."))
}

async function showList() {
  const node = dialog()
  if (!node) return

  const response = await fetch(node.dataset.listUrl, {
    headers: { Accept: "application/json" }
  })
  const data = await response.json().catch(() => ({ reminders: [] }))
  showResult(listMarkup(data.reminders || []))
}

function startDictation(button) {
  const Recognition = window.SpeechRecognition || window.webkitSpeechRecognition
  const field = input()

  if (!Recognition || !field) {
    window.alert("Este navegador não reconhece voz. Use Chrome ou Edge, ou escreva para o Maestro.")
    return
  }

  const recognition = new Recognition()
  recognition.lang = "pt-BR"
  recognition.interimResults = false
  recognition.maxAlternatives = 1
  button.disabled = true
  recognition.onresult = (event) => {
    const spoken = event.results[0]?.[0]?.transcript
    if (spoken) field.value = spoken
  }
  recognition.onend = () => {
    button.disabled = false
  }
  recognition.start()
}

function showFiredToasts(cards) {
  if (!window.MaestroToast || !Array.isArray(cards)) return

  cards.forEach((card) => {
    window.MaestroToast.show({
      kind: "maestro",
      title: "Lembrete",
      message: `${card.title} · ${card.time_label}`,
      icon_url: markUrl(),
      duration: 8000
    })
  })
}

async function pollDue() {
  const node = dialog()
  if (!node?.dataset.dueUrl) return

  const { data } = await postJSON(node.dataset.dueUrl, {})
  showFiredToasts(data.fired || [])
}

function bindQuick() {
  if (window.__maestroQuickBound) return
  window.__maestroQuickBound = true

  document.addEventListener("click", (event) => {
    if (event.target.closest("[data-maestro-quick-open]")) {
      event.preventDefault()
      openQuick()
      return
    }

    if (event.target.closest("[data-maestro-quick-close]")) {
      if (event.target.closest("a")) return
      event.preventDefault()
      closeQuick()
      return
    }

    const chip = event.target.closest("[data-maestro-quick-chip]")
    if (chip) {
      event.preventDefault()
      const kind = chip.dataset.maestroQuickChip
      const field = input()
      if (kind === "lembrete") {
        openQuick({ reminder: true })
        return
      }
      if (field) {
        field.value = kind
        field.form?.requestSubmit()
      }
      return
    }

    const undo = event.target.closest("[data-reminder-undo]")
    if (undo) {
      event.preventDefault()
      undoReminder(undo.dataset.reminderUndo)
      return
    }

    if (event.target.closest("[data-maestro-quick-list]")) {
      event.preventDefault()
      openQuick()
      showList()
      return
    }

    if (event.target.closest("[data-maestro-quick-mic]")) {
      event.preventDefault()
      startDictation(event.target.closest("[data-maestro-quick-mic]"))
    }
  })

  document.addEventListener("submit", (event) => {
    if (!event.target.closest("[data-maestro-quick-form]")) return
    submitQuick(event)
  })

  document.addEventListener("keydown", (event) => {
    const node = dialog()
    if (!node?.open) return
    if (event.key === "Escape") {
      event.preventDefault()
      closeQuick()
    }
  })

  document.addEventListener("click", (event) => {
    const node = dialog()
    if (event.target === node) closeQuick()
  })
}

bindQuick()

document.addEventListener("turbo:load", () => {
  closeQuick()
  const box = resultBox()
  if (box) box.innerHTML = ""
})

setInterval(pollDue, 45000)
