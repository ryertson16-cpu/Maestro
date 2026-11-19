function guardSiageExtension() {
  document.addEventListener("click", (event) => {
    const botao = event.target.closest("[data-siage-open]")
    if (!botao) return
    if (document.documentElement.dataset.siageExtensao === "pronta") return
    event.preventDefault()
    event.stopPropagation()
    document.querySelector("[data-siage-extension-missing]")?.removeAttribute("hidden")
  }, true)

  document.addEventListener("maestro-siage-falhou", () => {
    document.querySelector("[data-siage-extension-missing]")?.removeAttribute("hidden")
  })
}

function startSiageRosterPoll() {
  const root = document.querySelector("[data-siage-roster-poll]")
  if (!root) return

  const url = root.getAttribute("data-siage-roster-poll")
  const wait = document.querySelector("[data-siage-roster-wait]")
  if (!url) return

  document.addEventListener("click", (event) => {
    if (event.target.closest("[data-siage-open]")) wait?.removeAttribute("hidden")
  })

  window.setInterval(async () => {
    try {
      const response = await fetch(url, {
        headers: { Accept: "application/json" },
        credentials: "same-origin"
      })
      if (!response.ok) return
      const data = await response.json()
      if (data.ready) window.location.reload()
    } catch (_error) {}
  }, 2500)
}

document.addEventListener("turbo:load", startSiageRosterPoll)
guardSiageExtension()
startSiageRosterPoll()
