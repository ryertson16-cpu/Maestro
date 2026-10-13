function csrfToken() {
  const meta = document.querySelector('meta[name="csrf-token"]')

  return meta ? meta.content : ""
}

function iconForStatus(status) {
  const icons = {
    present: `
      <svg class="attendance-icon attendance-icon-present"
           viewBox="0 0 24 24"
           aria-hidden="true">
        <path d="M5 12.5l4 4L19 7" />
      </svg>
    `,

    absent: `
      <svg class="attendance-icon attendance-icon-absent"
           viewBox="0 0 24 24"
           aria-hidden="true">
        <path d="M6 6l12 12M18 6L6 18" />
      </svg>
    `,

    justified: `
      <svg class="attendance-icon attendance-icon-justified"
           viewBox="0 0 24 24"
           aria-hidden="true">
        <path d="M7 3h7l4 4v14H7z" />
        <path d="M14 3v5h4M10 13h5M10 17h5" />
      </svg>
    `,

    late: `
      <svg class="attendance-icon attendance-icon-late"
           viewBox="0 0 24 24"
           aria-hidden="true">
        <circle cx="12" cy="12" r="8" />
        <path d="M12 7v5l3 2" />
      </svg>
    `
  }

  return icons[status] || '<span class="attendance-empty-icon">+</span>'
}

function updateAttendanceCell(cell, status) {
  const button = cell.querySelector("[data-attendance-button]")

  cell.classList.remove(
    "status-pending",
    "status-present",
    "status-absent",
    "status-justified",
    "status-late"
  )

  cell.classList.add(`status-${status || "pending"}`)

  button.innerHTML = iconForStatus(status)
}

function updatePercentage(enrollmentId, percentage) {
  const percentageCell = document.querySelector(
    `[data-percentage-for="${enrollmentId}"]`
  )

  if (!percentageCell) return

  percentageCell.textContent = `${percentage}%`
}

async function saveAttendanceCell(cell, status) {
  const payload = {
    classroom_id: cell.dataset.classroomId,
    enrollment_id: cell.dataset.enrollmentId,
    attendance_date: cell.dataset.attendanceDate,
    status: status
  }

  if (!navigator.onLine && window.MaestroOffline) {
    window.MaestroOffline.enqueueCell(payload)
    updateAttendanceCell(cell, status)
    return
  }

  const response = await fetch("/attendance_records/save_cell", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Accept": "application/json",
      "X-CSRF-Token": csrfToken()
    },
    body: JSON.stringify(payload)
  })

  const data = await response.json()

  if (!response.ok || !data.success) {
    throw new Error(data.error || "Não foi possível salvar a frequência.")
  }

  updateAttendanceCell(cell, data.status)
  updatePercentage(cell.dataset.enrollmentId, data.percentage)
}

function initializeAttendanceGrid() {
  const cells = document.querySelectorAll("[data-attendance-cell]")

  cells.forEach((cell) => {
    const button = cell.querySelector("[data-attendance-button]")
    const select = cell.querySelector("[data-attendance-select]")

    button.addEventListener("click", () => {
      select.focus()
      select.click()
    })

    select.addEventListener("change", async () => {
      const status = select.value

      if (!status) return

      cell.classList.add("is-saving")

      try {
        await saveAttendanceCell(cell, status)
      } catch (error) {
        window.alert(error.message)
      } finally {
        cell.classList.remove("is-saving")
      }
    })
  })
}

document.addEventListener("turbo:load", initializeAttendanceGrid)