document.addEventListener("input", (event) => {
  if (!event.target.matches("[data-student-filter]")) return

  const needle = event.target.value.toString().trim().toLowerCase()
  document.querySelectorAll(".correction-student").forEach((link) => {
    const name = (link.getAttribute("data-student-name") || link.textContent || "").toLowerCase()
    link.hidden = needle !== "" && !name.includes(needle)
  })
})
