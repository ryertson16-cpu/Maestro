const THEME_KEY = "maestro-theme"
const THEME_COLOR = {
  day: "#5b4bdb",
  night: "#12141c"
}

function currentTheme() {
  return document.documentElement.getAttribute("data-theme") === "night" ? "night" : "day"
}

function applyTheme(theme) {
  if (theme === "night") {
    document.documentElement.setAttribute("data-theme", "night")
  } else {
    document.documentElement.removeAttribute("data-theme")
  }

  try {
    localStorage.setItem(THEME_KEY, theme)
  } catch (_error) {
    // ignore storage errors
  }

  const meta = document.querySelector('meta[name="theme-color"]')
  if (meta) meta.content = THEME_COLOR[theme]

  syncSwitches()
}

function syncSwitches() {
  const night = currentTheme() === "night"

  document.querySelectorAll("[data-theme-toggle]").forEach((button) => {
    button.setAttribute("aria-checked", night ? "true" : "false")
  })

  document.querySelectorAll("[data-theme-mode-label]").forEach((label) => {
    label.textContent = night ? "Modo noturno" : "Modo dia"
  })
}

document.addEventListener("click", (event) => {
  const button = event.target.closest("[data-theme-toggle]")
  if (!button) return

  event.preventDefault()
  applyTheme(currentTheme() === "night" ? "day" : "night")
})

document.addEventListener("turbo:load", syncSwitches)
syncSwitches()
