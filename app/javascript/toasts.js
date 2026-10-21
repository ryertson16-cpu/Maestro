const TITLES = {
  success: "Sucesso",
  error: "Erro",
  attention: "Atenção",
  maestro: "Maestro"
}

const ICONS = {
  success: `
    <svg viewBox="0 0 24 24" aria-hidden="true">
      <circle cx="12" cy="12" r="10" fill="#22c55e"/>
      <path d="M7.5 12.5l3 3 6-6" fill="none" stroke="#fff" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/>
    </svg>
  `,
  error: `
    <svg viewBox="0 0 24 24" aria-hidden="true">
      <circle cx="12" cy="12" r="10" fill="#ef4444"/>
      <path d="M12 7v6" fill="none" stroke="#fff" stroke-width="2.2" stroke-linecap="round"/>
      <circle cx="12" cy="16.4" r="1.15" fill="#fff"/>
    </svg>
  `,
  attention: `
    <svg viewBox="0 0 24 24" aria-hidden="true">
      <path d="M12 3.2L22.4 21H1.6L12 3.2z" fill="#f5c518"/>
      <rect x="11" y="9" width="2" height="6.2" rx="1" fill="#1c1917"/>
      <circle cx="12" cy="17.6" r="1.15" fill="#1c1917"/>
    </svg>
  `
}

const DURATIONS = {
  success: 4200,
  error: 6500,
  attention: 5200,
  maestro: 7000
}

const pendingMaestro = []

function host() {
  let node = document.getElementById("toast-host")
  if (!node) {
    node = document.createElement("div")
    node.id = "toast-host"
    node.className = "toast-host"
    node.setAttribute("aria-live", "polite")
    document.body.appendChild(node)
  }
  return node
}

function kindOf(options = {}) {
  const kind = String(options.kind || "")
  if (["success", "error", "attention", "maestro"].includes(kind)) return kind
  return "attention"
}

function waitsForOthers(options = {}) {
  return Boolean(options.wait_for_others) && kindOf(options) === "maestro"
}

function otherToastsVisible() {
  return Array.from(host().querySelectorAll(".toast")).some((toast) => {
    return !toast.classList.contains("toast-maestro") && !toast.classList.contains("is-leaving")
  })
}

function iconMarkup(kind, options = {}) {
  if (options.icon_url) {
    return `<img src="${escapeHtml(String(options.icon_url))}" alt="" class="toast-maestro-mark">`
  }

  return ICONS[kind] || ICONS.attention
}

function recapLines(options = {}) {
  const lines = Array.isArray(options.lines) ? options.lines : []
  return lines.filter((line) => line && (line.label || line.parts))
}

function renderParts(parts) {
  return (Array.isArray(parts) ? parts : [])
    .map((part) => {
      const text = escapeHtml(String(part.text || part.t || ""))
      if (!text) return ""
      return part.bold ? `<strong>${text}</strong>` : text
    })
    .join("")
}

function recapMarkup(options = {}) {
  const lines = recapLines(options)
  if (!lines.length) return ""

  const items = lines
    .map((line) => {
      const label = escapeHtml(String(line.label || ""))
      const body = renderParts(line.parts)
      const labelHtml = label ? `<strong class="toast-recap-label">${label}:</strong> ` : ""
      return `
        <li class="toast-recap-item">
          <span class="toast-recap-check" aria-hidden="true">
            <svg viewBox="0 0 16 16">
              <path d="M3.2 8.3l3.1 3.1 6.5-6.6" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/>
            </svg>
          </span>
          <p>${labelHtml}${body}</p>
        </li>
      `
    })
    .join("")

  return `<ul class="toast-recap">${items}</ul>`
}

function show(options = {}) {
  const message = String(options.message || "").trim()
  const recap = recapMarkup(options)
  if (!message && !recap) return

  if (waitsForOthers(options)) {
    pendingMaestro.push({ ...options, wait_for_others: false })
    flushMaestro()
    return
  }

  const kind = kindOf(options)
  const title = options.title || TITLES[kind]
  const toast = document.createElement("div")
  toast.className = `toast toast-${kind}${recap ? " toast-has-recap" : ""}`
  toast.setAttribute("role", kind === "error" ? "alert" : "status")
  toast.innerHTML = `
    <span class="toast-icon">${iconMarkup(kind, options)}</span>
    <div class="toast-copy">
      <strong>${escapeHtml(title)}</strong>
      ${message ? `<p>${escapeHtml(message)}</p>` : ""}
      ${recap}
    </div>
    <div class="toast-actions">
      ${
        options.href
          ? `<a class="toast-dismiss toast-action" href="${escapeHtml(options.href)}">${escapeHtml(options.action || "Abrir")}</a>`
          : ""
      }
      <button type="button" class="toast-dismiss">Entendi</button>
    </div>
  `

  const dismiss = () => hide(toast)
  toast.querySelectorAll("button.toast-dismiss").forEach((button) => {
    button.addEventListener("click", dismiss)
  })
  host().appendChild(toast)

  const timerMs = Object.prototype.hasOwnProperty.call(options, "duration")
    ? Number(options.duration)
    : DURATIONS[kind]

  if (Number.isFinite(timerMs) && timerMs > 0) {
    const timer = window.setTimeout(dismiss, timerMs)
    toast.dataset.timer = String(timer)
  }
}

function hide(toast) {
  if (!toast || toast.classList.contains("is-leaving")) return
  window.clearTimeout(Number(toast.dataset.timer))
  toast.classList.add("is-leaving")
  window.setTimeout(() => {
    toast.remove()
    flushMaestro()
  }, 220)
}

function flushMaestro() {
  if (!pendingMaestro.length) return
  if (otherToastsVisible()) return

  const next = pendingMaestro.shift()
  show(next)
}

function escapeHtml(value) {
  return value
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
}

function consumeServerToasts() {
  const node = document.getElementById("toast-flashes")
  if (!node || node.dataset.consumed === "true") return
  node.dataset.consumed = "true"
  pendingMaestro.length = 0

  let items = []
  try {
    items = JSON.parse(node.textContent || "[]")
  } catch (_error) {
    items = []
  }

  items.forEach((item) => show(item))
  flushMaestro()
}

window.MaestroToast = { show }

document.addEventListener("turbo:load", consumeServerToasts)
document.addEventListener("DOMContentLoaded", consumeServerToasts)
