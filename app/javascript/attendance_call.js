function rowStatus(row) {
  const late = row.querySelector("[data-attendance-late]")
  const justified = row.querySelector("[data-attendance-justified]")
  const sw = row.querySelector("[data-attendance-switch]")

  if (justified?.checked) return "justified"
  if (late?.checked) return "late"
  return sw?.getAttribute("aria-checked") === "true" ? "present" : "absent"
}

function paintRow(row, status) {
  const hidden = row.querySelector("[data-attendance-status]")
  const cell = row.querySelector(".attendance-status-cell")
  const sw = row.querySelector("[data-attendance-switch]")
  const late = row.querySelector("[data-attendance-late]")
  const justified = row.querySelector("[data-attendance-justified]")

  if (hidden) hidden.value = status
  if (late) late.checked = status === "late"
  if (justified) justified.checked = status === "justified"
  if (sw) {
    const on = status !== "absent"
    sw.setAttribute("aria-checked", on ? "true" : "false")
    sw.setAttribute("aria-label", {
      present: "Presente",
      absent: "Falta",
      justified: "Falta justificada",
      late: "Atrasado"
    }[status] || "Presença")
  }
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
    const status = row.querySelector("[data-attendance-status]")?.value || rowStatus(row)
    if (status === "present" || status === "absent" || status === "justified" || status === "late") {
      counts[status] += 1
    }
  })

  root.querySelectorAll("[data-summary-count]").forEach((el) => {
    const key = el.dataset.summaryCount
    if (key in counts) el.textContent = String(counts[key])
  })
}

function syncRow(row) {
  paintRow(row, rowStatus(row))
  updateSummary()
}

document.addEventListener("click", (event) => {
  const sw = event.target.closest("[data-attendance-switch]")
  if (sw) {
    event.preventDefault()
    const row = sw.closest("[data-attendance-row]")
    if (!row) return
    const late = row.querySelector("[data-attendance-late]")
    const justified = row.querySelector("[data-attendance-justified]")
    if (late) late.checked = false
    if (justified) justified.checked = false
    const on = sw.getAttribute("aria-checked") === "true"
    sw.setAttribute("aria-checked", on ? "false" : "true")
    syncRow(row)
    return
  }

  const marcarTodos = event.target.closest("[data-attendance-mark-all]")
  if (marcarTodos) {
    event.preventDefault()
    const root = marcarTodos.closest("[data-attendance-block]") || document
    root.querySelectorAll("[data-attendance-row]").forEach((row) => {
      paintRow(row, "present")
    })
    updateSummary()
  }
})

document.addEventListener("change", (event) => {
  const late = event.target.closest("[data-attendance-late]")
  const justified = event.target.closest("[data-attendance-justified]")
  if (!late && !justified) return

  const row = event.target.closest("[data-attendance-row]")
  if (!row) return

  if (late?.checked) {
    const other = row.querySelector("[data-attendance-justified]")
    if (other) other.checked = false
  }
  if (justified?.checked) {
    const other = row.querySelector("[data-attendance-late]")
    if (other) other.checked = false
  }

  const sw = row.querySelector("[data-attendance-switch]")
  if ((late?.checked || justified?.checked) && sw) {
    sw.setAttribute("aria-checked", "true")
  }
  syncRow(row)
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
