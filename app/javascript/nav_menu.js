function navRoot() {
  return document.querySelector("[data-main-nav]")
}

function closeAll(except) {
  document.querySelectorAll("[data-nav-item]").forEach((item) => {
    if (item === except) return
    item.classList.remove("is-open")
    const caret = item.querySelector("[data-nav-caret]")
    const panel = item.querySelector("[data-nav-panel]")
    if (caret) caret.setAttribute("aria-expanded", "false")
    if (panel) panel.hidden = true
  })
}

function toggleItem(item) {
  const open = !item.classList.contains("is-open")
  closeAll(open ? item : null)
  const caret = item.querySelector("[data-nav-caret]")
  const panel = item.querySelector("[data-nav-panel]")
  item.classList.toggle("is-open", open)
  if (caret) caret.setAttribute("aria-expanded", open ? "true" : "false")
  if (panel) panel.hidden = !open
}

document.addEventListener("click", (event) => {
  const caret = event.target.closest("[data-nav-caret]")
  if (caret) {
    event.preventDefault()
    const item = caret.closest("[data-nav-item]")
    if (item) toggleItem(item)
    return
  }

  if (!event.target.closest("[data-nav-item]")) closeAll()
})

document.addEventListener("keydown", (event) => {
  if (event.key === "Escape") closeAll()
})

document.addEventListener("turbo:load", () => closeAll())
