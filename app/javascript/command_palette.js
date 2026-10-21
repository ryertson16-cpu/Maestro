function palette() {
  return document.querySelector("[data-command-palette]")
}

function paletteInput() {
  return document.querySelector("[data-command-palette-input]")
}

function visibleItems() {
  return Array.from(
    document.querySelectorAll(
      "[data-command-group]:not([hidden]) [data-command-item]:not([hidden])"
    )
  )
}

function normalize(value) {
  return value
    .toString()
    .toLowerCase()
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
}

function isTypingTarget(target) {
  if (!(target instanceof HTMLElement)) return false
  if (target.closest("[data-command-palette]")) return false

  const tag = target.tagName
  return (
    tag === "INPUT" ||
    tag === "TEXTAREA" ||
    tag === "SELECT" ||
    target.isContentEditable
  )
}

function isMac() {
  return /Mac|iPhone|iPad/.test(navigator.platform || "")
}

function syncHotkeyLabels() {
  const label = isMac() ? "⌘K" : "Ctrl K"
  document.querySelectorAll("[data-command-palette-hotkey]").forEach((node) => {
    node.textContent = label
  })
}

function filterItems(query) {
  const dialog = palette()
  if (!dialog) return

  const needle = normalize(query.trim())
  const groups = dialog.querySelectorAll("[data-command-group]")
  const empty = dialog.querySelector("[data-command-palette-empty]")
  let visible = 0

  groups.forEach((group) => {
    const items = group.querySelectorAll("[data-command-item]")
    let groupVisible = 0

    items.forEach((item) => {
      const haystack = normalize(item.getAttribute("data-search") || item.textContent || "")
      const match = needle === "" || haystack.includes(needle)
      item.hidden = !match
      if (match) groupVisible += 1
    })

    group.hidden = groupVisible === 0
    visible += groupVisible
  })

  if (empty) empty.hidden = visible > 0
  selectIndex(0)
}

function selectIndex(index) {
  const items = visibleItems()
  items.forEach((item) => item.classList.remove("is-active"))
  if (items.length === 0) return

  const next = items[Math.max(0, Math.min(index, items.length - 1))]
  next.classList.add("is-active")
  next.scrollIntoView({ block: "nearest" })
}

function activeIndex() {
  const items = visibleItems()
  return items.findIndex((item) => item.classList.contains("is-active"))
}

function move(delta) {
  const items = visibleItems()
  if (items.length === 0) return
  const current = activeIndex()
  const next = current < 0 ? 0 : (current + delta + items.length) % items.length
  selectIndex(next)
}

function activateItem(item) {
  if (!item) return

  const action = item.getAttribute("data-command-action")
  if (action === "theme") {
    document.querySelector("[data-theme-toggle]")?.click()
    closePalette()
    return
  }

  if (action === "maestro-quick") {
    closePalette()
    document.querySelector("[data-maestro-quick-open]")?.click()
    return
  }

  if (item.tagName === "A") {
    closePalette()
    item.click()
  }
}

function openPalette() {
  const dialog = palette()
  const input = paletteInput()
  if (!dialog || !input) return

  if (!dialog.open) dialog.showModal()
  input.value = ""
  filterItems("")
  input.focus()
}

function closePalette() {
  const dialog = palette()
  if (dialog?.open) dialog.close()
}

document.addEventListener("click", (event) => {
  if (event.target.closest("[data-command-palette-open]")) {
    event.preventDefault()
    openPalette()
    return
  }

  const item = event.target.closest("[data-command-item]")
  if (item?.getAttribute("data-command-action")) {
    event.preventDefault()
    activateItem(item)
  }
})

document.addEventListener("keydown", (event) => {
  const dialog = palette()
  const open = Boolean(dialog?.open)

  if ((event.ctrlKey || event.metaKey) && event.key.toLowerCase() === "k") {
    if (!palette()) return
    event.preventDefault()
    if (open) closePalette()
    else openPalette()
    return
  }

  if (!open) {
    if (event.key === "/" && !event.ctrlKey && !event.metaKey && !event.altKey && !isTypingTarget(event.target)) {
      event.preventDefault()
      openPalette()
    }
    return
  }

  if (event.key === "Escape") {
    event.preventDefault()
    closePalette()
    return
  }

  if (event.key === "ArrowDown") {
    event.preventDefault()
    move(1)
    return
  }

  if (event.key === "ArrowUp") {
    event.preventDefault()
    move(-1)
    return
  }

  if (event.key === "Enter") {
    const items = visibleItems()
    const current = items[activeIndex()] || items[0]
    if (!current) return
    event.preventDefault()
    activateItem(current)
  }
})

document.addEventListener("input", (event) => {
  if (!event.target.matches("[data-command-palette-input]")) return
  filterItems(event.target.value)
})

document.addEventListener("mouseover", (event) => {
  const item = event.target.closest("[data-command-item]")
  if (!item || item.hidden) return
  const items = visibleItems()
  const index = items.indexOf(item)
  if (index >= 0) selectIndex(index)
})

document.addEventListener("click", (event) => {
  const dialog = palette()
  if (event.target === dialog) closePalette()
})

document.addEventListener("turbo:load", () => {
  closePalette()
  syncHotkeyLabels()
})

document.addEventListener("turbo:before-cache", closePalette)

syncHotkeyLabels()
