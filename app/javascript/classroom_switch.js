document.addEventListener("change", (event) => {
  const select = event.target.closest("[data-classroom-switch]")
  if (!(select instanceof HTMLSelectElement)) return

  const url = select.value
  if (url) window.location.assign(url)
})
