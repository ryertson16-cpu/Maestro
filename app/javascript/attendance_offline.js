const QUEUE_KEY = "maestro-sync-queue"
const LEGACY_QUEUE_KEY = "maestro-attendance-queue"

function readQueue() {
  try {
    const current = JSON.parse(localStorage.getItem(QUEUE_KEY) || "[]")
    const legacy = JSON.parse(localStorage.getItem(LEGACY_QUEUE_KEY) || "[]")
    if (legacy.length) {
      const merged = current.concat(legacy)
      localStorage.removeItem(LEGACY_QUEUE_KEY)
      localStorage.setItem(QUEUE_KEY, JSON.stringify(merged))
      return merged
    }
    return current
  } catch (_error) {
    return []
  }
}

function writeQueue(items) {
  localStorage.setItem(QUEUE_KEY, JSON.stringify(items))
}

function queueKindLabel(kind) {
  if (kind === "grades") return "nota"
  return "chamada"
}

function showOfflineBanner(message, queued) {
  let banner = document.querySelector("[data-offline-banner]")
  if (!banner) {
    banner = document.createElement("div")
    banner.className = "offline-banner"
    banner.dataset.offlineBanner = "true"
    document.body.prepend(banner)
  }
  banner.hidden = false
  banner.classList.toggle("is-ok", /fila está vazia/.test(message))
  const kinds = Array.from(
    new Set((queued || readQueue()).map((item) => queueKindLabel(item.kind)))
  )
  const extra = kinds.length ? ` Aguardando: ${kinds.join(" e ")}.` : ""
  banner.textContent = message + extra
}

function hideOfflineBanner() {
  const banner = document.querySelector("[data-offline-banner]")
  if (banner) banner.hidden = true
}

function enqueue(item) {
  const queue = readQueue()
  queue.push(item)
  writeQueue(queue)
  const label = queueKindLabel(item.kind)
  showOfflineBanner(
    `Sem rede. ${queue.length} lançamento(s) de ${label} ficam neste aparelho até a conexão voltar.`,
    queue
  )
}

window.MaestroOffline = {
  enqueueCell(payload) {
    enqueue({
      kind: "attendance",
      url: "/attendance_records/save_cell",
      headers: {
        "Content-Type": "application/json",
        Accept: "application/json",
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content || ""
      },
      body: JSON.stringify(payload)
    })
  }
}

async function flushQueue() {
  const queue = readQueue()
  if (!queue.length) {
    if (navigator.onLine) hideOfflineBanner()
    return
  }

  const remaining = []
  let synced = 0
  for (const item of queue) {
    try {
      const response = await fetch(item.url, {
        method: "POST",
        headers: item.headers,
        body: item.body
      })
      if (!response.ok) remaining.push(item)
      else synced += 1
    } catch (_error) {
      remaining.push(item)
    }
  }

  writeQueue(remaining)
  if (remaining.length) {
    showOfflineBanner(
      `${remaining.length} lançamento(s) ainda aguardam rede.`,
      remaining
    )
  } else if (navigator.onLine) {
    showOfflineBanner(
      synced > 1
        ? `${synced} lançamentos subiram. A fila está vazia.`
        : "Lançamento sincronizado. A fila está vazia."
    )
    window.setTimeout(hideOfflineBanner, 2800)
  }
}

document.addEventListener("submit", (event) => {
  const form = event.target
  if (!(form instanceof HTMLFormElement)) return
  if (navigator.onLine) return

  const attendanceSave =
    form.action.includes("/attendance_records/save") &&
    form.method.toLowerCase() !== "get" &&
    !form.action.includes("save_and_export")
  const gradesSave = form.matches("[data-offline-grades-form]")

  if (!attendanceSave && !gradesSave) return

  event.preventDefault()
  enqueue({
    kind: gradesSave ? "grades" : "attendance",
    url: form.getAttribute("action"),
    headers: {
      "Content-Type": "application/x-www-form-urlencoded",
      "X-CSRF-Token": form.querySelector('input[name="authenticity_token"]')?.value || ""
    },
    body: new URLSearchParams(new FormData(form)).toString()
  })
})

window.addEventListener("online", flushQueue)
document.addEventListener("turbo:load", () => {
  const queue = readQueue()
  if (!navigator.onLine) {
    showOfflineBanner("Você está offline. Chamada e nota continuam neste aparelho.", queue)
  } else if (queue.length) {
    showOfflineBanner(`${queue.length} lançamento(s) na fila. Sincronizando…`, queue)
  }
  flushQueue()
})

if ("serviceWorker" in navigator) {
  window.addEventListener("load", () => {
    navigator.serviceWorker.register("/service-worker.js").catch(() => {})
  })
}
