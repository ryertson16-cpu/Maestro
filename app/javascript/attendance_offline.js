const QUEUE_KEY = "maestro-attendance-queue"

function readQueue() {
  try {
    return JSON.parse(localStorage.getItem(QUEUE_KEY) || "[]")
  } catch (_error) {
    return []
  }
}

function writeQueue(items) {
  localStorage.setItem(QUEUE_KEY, JSON.stringify(items))
}

function showOfflineBanner(message) {
  let banner = document.querySelector("[data-offline-banner]")
  if (!banner) {
    banner = document.createElement("div")
    banner.className = "offline-banner"
    banner.dataset.offlineBanner = "true"
    document.body.prepend(banner)
  }
  banner.hidden = false
  banner.textContent = message
}

function hideOfflineBanner() {
  const banner = document.querySelector("[data-offline-banner]")
  if (banner) banner.hidden = true
}

function enqueue(item) {
  const queue = readQueue()
  queue.push(item)
  writeQueue(queue)
  showOfflineBanner("Sem rede. A chamada fica neste aparelho até a conexão voltar.")
}

window.MaestroOffline = {
  enqueueCell(payload) {
    enqueue({
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
  for (const item of queue) {
    try {
      const response = await fetch(item.url, {
        method: "POST",
        headers: item.headers,
        body: item.body
      })
      if (!response.ok) remaining.push(item)
    } catch (_error) {
      remaining.push(item)
    }
  }

  writeQueue(remaining)
  if (remaining.length) {
    showOfflineBanner(`${remaining.length} lançamento(s) da chamada aguardando rede.`)
  } else if (navigator.onLine) {
    hideOfflineBanner()
  }
}

document.addEventListener("submit", (event) => {
  const form = event.target
  if (!(form instanceof HTMLFormElement)) return
  if (!form.action.includes("/attendance_records/save")) return
  if (form.method.toLowerCase() === "get") return
  if (form.action.includes("save_and_export")) return
  if (navigator.onLine) return

  event.preventDefault()
  enqueue({
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
  if (!navigator.onLine) {
    showOfflineBanner("Você está offline. A chamada continua neste aparelho.")
  }
  flushQueue()
})

if ("serviceWorker" in navigator) {
  window.addEventListener("load", () => {
    navigator.serviceWorker.register("/service-worker.js").catch(() => {})
  })
}
