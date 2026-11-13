document.addEventListener("input", (event) => {
  if (!event.target.matches("[data-student-filter]")) return

  const needle = event.target.value.toString().trim().toLowerCase()
  document.querySelectorAll(".correction-student").forEach((link) => {
    const name = (link.getAttribute("data-student-name") || link.textContent || "").toLowerCase()
    link.hidden = needle !== "" && !name.includes(needle)
  })
})

document.addEventListener("change", (event) => {
  const input = event.target
  if (!(input instanceof HTMLInputElement) || !input.matches(".omr-bubble input")) return

  const sheet = input.closest("[data-omr-sheet]")
  const row = input.closest(".omr-row")
  if (!sheet || !row) return

  paintRow(sheet, row, input.value.toUpperCase())
  paintScore(sheet)
})

document.querySelectorAll("[data-omr-sheet]").forEach((sheet) => paintScore(sheet))

function paintRow(sheet, row, chosen) {
  const reveal = sheet.getAttribute("data-omr-reveal") === "1"
  const expected = (row.getAttribute("data-expected") || "").toUpperCase()
  const letter = chosen.toUpperCase()
  row.classList.toggle("is-blank", letter === "")
  row.querySelectorAll(".omr-bubble").forEach((bubble) => {
    const choice = (bubble.getAttribute("data-letter") || "").toUpperCase()
    bubble.classList.toggle("is-marked", choice === letter)
    bubble.classList.toggle("is-key", reveal && choice === expected)
    bubble.classList.toggle("is-wrong", reveal && choice === letter && choice !== expected)
  })
  const number = row.querySelector(".omr-num")
  number?.classList.toggle("is-wrong", reveal && letter !== "" && letter !== expected)
  number?.classList.toggle("is-unread", reveal && letter === "")
  const status = row.querySelector("[data-omr-status]")
  if (!status) return
  status.classList.toggle("is-hit", reveal && letter !== "" && letter === expected)
  status.classList.toggle("is-miss", reveal && letter !== "" && letter !== expected)
  status.classList.toggle("is-unread", reveal && letter === "")
  if (letter === "") status.textContent = "Não li esta questão"
  else if (!reveal || letter === expected) status.textContent = `Leu ${letter}`
  else status.textContent = `Leu ${letter} · certa ${expected}`
}

function paintScore(sheet) {
  const score = sheet.querySelector("[data-omr-score]")
  const count = sheet.querySelector("[data-omr-count]")
  if (!score || !count) return

  const rows = [ ...sheet.querySelectorAll(".omr-row") ]
  let earned = 0
  let hits = 0
  rows.forEach((row) => {
    const expected = (row.getAttribute("data-expected") || "").toUpperCase()
    const chosen = (row.querySelector(".omr-bubble input:checked")?.value || row.getAttribute("data-read") || "").toUpperCase()
    if (chosen && chosen === expected) {
      hits += 1
      earned += Number(row.getAttribute("data-points")) || 0
    }
  })
  const total = Number(sheet.getAttribute("data-objective-total")) || 0
  const ceiling = Number(sheet.getAttribute("data-ceiling")) || 10
  const raw = total > 0 ? (earned / total) * ceiling : 0
  const bounded = Math.max(0, Math.min(10, Math.round(raw * 10) / 10))
  score.textContent = bounded.toFixed(1).replace(".", ",")
  count.textContent = `${hits} de ${rows.length} certas`
}
