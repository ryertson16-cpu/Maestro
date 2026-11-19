function rowStatus(row) {
  const late = row.querySelector("[data-attendance-late]")
  const justified = row.querySelector("[data-attendance-justified]")
  const sw = row.querySelector("[data-attendance-switch]")

  if (justified && justified.checked) return "justified"
  if (late && late.checked) return "late"
  return sw && sw.checked ? "present" : "absent"
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
    cell.classList.remove("status-present", "status-absent", "status-justified", "status-late")
    cell.classList.add("status-" + status)
  }
}

function updateSummaryIn(root) {
  const counts = { total: 0, present: 0, absent: 0, justified: 0, late: 0 }

  root.querySelectorAll("[data-attendance-row]").forEach((row) => {
    counts.total += 1
    const status = rowStatus(row)
    if (Object.prototype.hasOwnProperty.call(counts, status)) counts[status] += 1
  })

  root.querySelectorAll("[data-summary-count]").forEach((el) => {
    const key = el.getAttribute("data-summary-count")
    if (Object.prototype.hasOwnProperty.call(counts, key)) el.textContent = String(counts[key])
  })
}

function updateSummary() {
  const blocks = document.querySelectorAll("[data-attendance-block]")
  if (blocks.length) {
    blocks.forEach((block) => updateSummaryIn(block))
    return
  }
  updateSummaryIn(document)
}

function applyChoice(row, target) {
  const sw = row.querySelector("[data-attendance-switch]")
  const late = row.querySelector("[data-attendance-late]")
  const justified = row.querySelector("[data-attendance-justified]")

  if (target === sw && sw && !sw.checked) {
    if (late) late.checked = false
    if (justified) justified.checked = false
  }
  if (target === late && late && late.checked) {
    if (justified) justified.checked = false
    if (sw) sw.checked = true
  }
  if (target === justified && justified && justified.checked) {
    if (late) late.checked = false
    if (sw) sw.checked = true
  }

  paintRow(row, rowStatus(row))
  updateSummaryIn(row.closest("[data-attendance-block]") || document)
}

function onAttendanceChange(event) {
  const target = event.target
  if (!target || !target.closest) return
  const row = target.closest("[data-attendance-row]")
  if (!row) return
  applyChoice(row, target)
}

document.addEventListener("click", (event) => {
  const source = event.target
  if (!source || !source.closest) return
  const marcarTodos = source.closest("[data-attendance-mark-all]")
  if (!marcarTodos) return

  event.preventDefault()
  const root = marcarTodos.closest("[data-attendance-block]") || document
  root.querySelectorAll("[data-attendance-row]").forEach((row) => paintRow(row, "present"))
  updateSummaryIn(root)
})

document.addEventListener("change", onAttendanceChange)
document.addEventListener("input", onAttendanceChange)
document.addEventListener("turbo:load", updateSummary)
document.addEventListener("turbo:render", updateSummary)
document.addEventListener("DOMContentLoaded", updateSummary)
updateSummary()