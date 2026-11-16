function rowStatus(row) {
  const late = row.querySelector("[data-attendance-late]")
  const justified = row.querySelector("[data-attendance-justified]")
  const sw = row.querySelector("[data-attendance-switch]")

  if (justified?.checked) return "justified"
  if (late?.checked) return "late"
  return sw?.checked ? "present" : "absent"
}

function paintRow(row, status) {
  const cell = row.querySelector(".attendance-status-cell")
  const sw = row.querySelector("[data-attendance-switch]")
  const late = row.querySelector("[data-attendance-late]")
  const justified = row.querySelector("[data-attendance-justified]")

  if (late) late.checked = status === "late"
  if (justified) justified.checked = status === "justified"
  if (sw) sw.checked = status !== "absent"
  if (cell) {
    cell.classList.remove(
      "status-present",
      "status-absent",
      "status-justified",
      "status-late"
    )
    cell.classList.add(`status-${status}`)
  }
}

function updateSummary() {
  const blocks = document.querySelectorAll("[data-attendance-block]")
  if (blocks.length) {
    blocks.forEach((block) => updateSummaryIn(block))
    return
  }

  updateSummaryIn(document)
}

function updateSummaryIn(root) {
  const counts = {
    total: 0,
    present: 0,
    absent: 0,
    justified: 0,
    late: 0,
    pending: 0
  }

  root.querySelectorAll("[data-attendance-row]").forEach((row) => {
    counts.total += 1
    const status = rowStatus(row)
    if (status === "present" || status === "absent" || status === "justified" || status === "late") {
      counts[status] += 1
    }
  })

  root.querySelectorAll("[data-summary-count]").forEach((el) => {
    const key = el.dataset.summaryCount
    if (key in counts) el.textContent = String(counts[key])
  })
}

document.addEventListener("click", (event) => {
  const marcarTodos = event.target.closest("[data-attendance-mark-all]")
  if (!marcarTodos) return

  event.preventDefault()
  const root = marcarTodos.closest("[data-attendance-block]") || document
  root.querySelectorAll("[data-attendance-row]").forEach((row) => {
    paintRow(row, "present")
  })
  updateSummary()
})

document.addEventListener("change", (event) => {
  const row = event.target.closest("[data-attendance-row]")
  if (!row) return

  const sw = row.querySelector("[data-attendance-switch]")
  const late = row.querySelector("[data-attendance-late]")
  const justified = row.querySelector("[data-attendance-justified]")
  const target = event.target

  if (target === sw && !sw.checked) {
    if (late) late.checked = false
    if (justified) justified.checked = false
  }
  if (target === late && late.checked) {
    if (justified) justified.checked = false
    if (sw) sw.checked = true
  }
  if (target === justified && justified.checked) {
    if (late) late.checked = false
    if (sw) sw.checked = true
  }

  const cell = row.querySelector(".attendance-status-cell")
  const status = rowStatus(row)
  if (cell) {
    cell.classList.remove("status-present", "status-absent", "status-justified", "status-late")
    cell.classList.add(`status-${status}`)
  }
  updateSummary()
})

function triggerSiageDownload() {
  const link = document.querySelector("[data-siage-auto-download]")
  if (!link || link.dataset.started === "true") return
  link.dataset.started = "true"
  link.click()
}

document.addEventListener("turbo:load", () => {
  updateSummary()
  triggerSiageDownload()
})
document.addEventListener("DOMContentLoaded", () => {
  updateSummary()
  triggerSiageDownload()
})
