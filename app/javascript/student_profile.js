function shortLabel(text, max = 16) {
  const value = String(text || "")
  if (value.length <= max) return value
  return `${value.slice(0, max - 1)}…`
}

function validValue(value) {
  return value !== null && value !== undefined && value !== "" && !Number.isNaN(Number(value))
}

function formatScore(value) {
  if (!validValue(value)) return "—"

  return new Intl.NumberFormat("pt-BR", {
    minimumFractionDigits: 1,
    maximumFractionDigits: 2
  }).format(Number(value))
}

function escapeHtml(value) {
  return String(value)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;")
}

function smoothPath(points) {
  if (points.length === 0) return ""
  if (points.length === 1) return `M ${points[0].x} ${points[0].y}`

  let d = `M ${points[0].x} ${points[0].y}`

  for (let i = 0; i < points.length - 1; i += 1) {
    const from = points[i]
    const to = points[i + 1]
    const midX = (from.x + to.x) / 2
    d += ` C ${midX} ${from.y}, ${midX} ${to.y}, ${to.x} ${to.y}`
  }

  return d
}

function latestPair(points) {
  const withBoth = [...points].reverse().find((item) => (
    validValue(item.score) && validValue(item.class_average)
  ))

  return withBoth || points.filter((item) => validValue(item.score) || validValue(item.class_average)).at(-1)
}

function bindPhotoUpload() {
  document.querySelectorAll("[data-student-photo-form]").forEach((form) => {
    const input = form.querySelector('input[type="file"]')
    if (!input || input.dataset.bound === "true") return

    input.dataset.bound = "true"
    input.addEventListener("change", () => {
      if (input.files?.length) form.requestSubmit()
    })
  })
}

function seriesPoints(items, key, xFor, y) {
  return items.flatMap((item, index) => {
    if (!validValue(item[key])) return []
    return [{ x: xFor(index), y: y(Number(item[key])), value: Number(item[key]) }]
  })
}

function renderLineChart(chart, items, labels) {
  const width = 760
  const height = 340
  const padding = { top: 28, right: 28, bottom: 54, left: 52 }
  const plotWidth = width - padding.left - padding.right
  const plotHeight = height - padding.top - padding.bottom
  const baseline = padding.top + plotHeight
  const maxValue = 10
  const y = (value) => padding.top + plotHeight - (value / maxValue) * plotHeight
  const xFor = (index) => {
    if (items.length === 1) return padding.left + plotWidth / 2
    return padding.left + (index / (items.length - 1)) * plotWidth
  }

  const grid = []
  for (let step = 0; step <= 10; step += 2) {
    const lineY = y(step)
    grid.push(`
      <line x1="${padding.left}" y1="${lineY}" x2="${width - padding.right}" y2="${lineY}" class="student-chart-grid"></line>
      <text x="${padding.left - 10}" y="${lineY + 4}" class="student-chart-axis-label" text-anchor="end">${step}</text>
    `)
  }

  const studentPoints = seriesPoints(items, "score", xFor, y)
  const classPoints = seriesPoints(items, "class_average", xFor, y)

  const labelNodes = items.map((item, index) => `
    <text x="${xFor(index)}" y="${baseline + 28}" class="student-chart-x-label" text-anchor="middle">
      ${escapeHtml(labels[index] || "")}
    </text>
  `)

  const dots = (points, klass) => points.map((point) => `
    <circle cx="${point.x}" cy="${point.y}" r="4.5" class="${klass}"></circle>
  `).join("")

  chart.setAttribute("viewBox", `0 0 ${width} ${height}`)
  chart.innerHTML = `
    <defs>
      <filter id="maestro-line-glow" x="-40%" y="-40%" width="180%" height="180%">
        <feGaussianBlur stdDeviation="4.5" result="blur"></feGaussianBlur>
        <feMerge>
          <feMergeNode in="blur"></feMergeNode>
          <feMergeNode in="SourceGraphic"></feMergeNode>
        </feMerge>
      </filter>
    </defs>
    ${grid.join("")}
    <line x1="${padding.left}" y1="${baseline}" x2="${width - padding.right}" y2="${baseline}" class="student-chart-axis"></line>
    <line x1="${padding.left}" y1="${padding.top}" x2="${padding.left}" y2="${baseline}" class="student-chart-axis"></line>
    <path d="${smoothPath(classPoints)}" class="student-chart-line student-chart-line-class" fill="none"></path>
    <path d="${smoothPath(studentPoints)}" class="student-chart-line student-chart-line-student" fill="none" filter="url(#maestro-line-glow)"></path>
    ${dots(classPoints, "student-chart-dot student-chart-dot-class")}
    ${dots(studentPoints, "student-chart-dot student-chart-dot-student")}
    ${labelNodes.join("")}
  `
}

function renderSummary(summary, title, data) {
  let differenceText = "Sem comparação"

  if (validValue(data?.score) && validValue(data?.class_average)) {
    const difference = Number(data.score) - Number(data.class_average)

    if (difference > 0) differenceText = `+${formatScore(difference)} acima da turma`
    else if (difference < 0) differenceText = `${formatScore(Math.abs(difference))} abaixo da turma`
    else differenceText = "Igual à média da turma"
  }

  summary.innerHTML = `
    <div class="grade-history-summary-title">
      <strong>${escapeHtml(title)}</strong>
    </div>
    <div class="grade-history-summary-item">
      <span>Aluno</span>
      <strong>${formatScore(data?.score)}</strong>
    </div>
    <div class="grade-history-summary-item">
      <span>Média da turma</span>
      <strong>${formatScore(data?.class_average)}</strong>
    </div>
    <div class="grade-history-summary-item grade-history-difference">
      <span>Comparação</span>
      <strong>${escapeHtml(differenceText)}</strong>
    </div>
  `
}

function bindGradeChart() {
  const container = document.getElementById("student-grade-history")
  if (!container) return

  if (container.dataset.chartReady === "true") return
  container.dataset.chartReady = "true"

  let history
  try {
    history = JSON.parse(container.dataset.gradeHistory || "{}")
  } catch {
    return
  }

  const bimesters = Array.isArray(history.bimesters) ? history.bimesters : []
  const activities = (Array.isArray(history.activities) ? history.activities : [])
    .slice()
    .sort((a, b) => String(a.sort_date || "").localeCompare(String(b.sort_date || "")))

  const chart = document.getElementById("grade-history-chart")
  const summary = document.getElementById("grade-history-summary")
  const emptyState = document.getElementById("grade-history-empty")
  const chartCard = container.querySelector(".grade-history-chart-card")
  const modeButtons = container.querySelectorAll("[data-grade-mode]")

  if (!chart || !summary || !emptyState || !chartCard) return

  const hasSeries = (items) => items.some((item) => validValue(item.score) || validValue(item.class_average))

  function currentMode() {
    return container.dataset.currentMode || "bimester"
  }

  function setMode(mode) {
    container.dataset.currentMode = mode
    modeButtons.forEach((button) => {
      button.classList.toggle("is-active", button.dataset.gradeMode === mode)
    })
  }

  function render() {
    const mode = currentMode()
    const items = mode === "activity" ? activities : bimesters
    const labels = mode === "activity"
      ? items.map((item) => shortLabel(item.title || "Atividade"))
      : items.map((item) => item.label || `${item.bimester}º`)

    if (!hasSeries(items)) {
      chartCard.hidden = true
      emptyState.hidden = false
      summary.innerHTML = ""
      chart.innerHTML = ""
      return
    }

    chartCard.hidden = false
    emptyState.hidden = true
    renderLineChart(chart, items, labels)

    const focus = latestPair(items)
    const title = mode === "activity"
      ? (focus?.title || "Atividades")
      : "Evolução bimestral"
    renderSummary(summary, title, focus || {})
  }

  modeButtons.forEach((button) => {
    button.addEventListener("click", (event) => {
      event.preventDefault()
      setMode(button.dataset.gradeMode)
      render()
    })
  })

  const preferred = hasSeries(bimesters) ? "bimester" : "activity"
  setMode(preferred)
  render()
}

function bootStudentProfile() {
  bindPhotoUpload()
  bindGradeChart()
}

document.addEventListener("turbo:load", bootStudentProfile)
