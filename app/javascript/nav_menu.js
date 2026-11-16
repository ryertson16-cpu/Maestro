function closeAll(except) {
  document.querySelectorAll("[data-nav-item] details").forEach((details) => {
    if (details === except) return
    details.open = false
  })
}

document.addEventListener("click", (event) => {
  const caret = event.target.closest("[data-nav-caret]")
  if (caret) {
    closeAll(caret.closest("details"))
    return
  }

  if (!event.target.closest("[data-nav-item]")) closeAll()
})

document.addEventListener("keydown", (event) => {
  if (event.key === "Escape") closeAll()
})

document.addEventListener("turbo:load", () => closeAll())
