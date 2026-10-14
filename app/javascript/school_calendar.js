function schoolCalendarRoot() {
  return document.querySelector("[data-school-calendar]")
}

function selectedIso() {
  return schoolCalendarRoot()?.dataset.selectedDay
}

function selectedButton() {
  const root = schoolCalendarRoot()
  if (!root) return null
  return root.querySelector(`[data-calendar-day][data-date="${selectedIso()}"]`)
}

function parseJsonData(key, fallback) {
  try {
    return JSON.parse(schoolCalendarRoot()?.dataset[key] || "")
  } catch (_error) {
    return fallback
  }
}

function formatDate(iso) {
  const parts = String(iso || "").split("-")
  if (parts.length !== 3) return iso
  return `${parts[2]}/${parts[1]}/${parts[0]}`
}

function formPeriod() {
  const value = Number.parseInt(document.querySelector("[data-grade-period]")?.value, 10)
  if (Number.isInteger(value) && value > 0) return `${value}º tempo`
  return null
}

function isSchoolDay(button) {
  return button?.dataset.school === "true"
}

function syncTurmaBlock(button) {
  const iso = button.dataset.date
  document.querySelectorAll("[data-calendar-date]").forEach((field) => {
    field.value = iso
  })
  const pretty = button.getAttribute("title")?.split(" · ")[0] || formatDate(iso)
  document.querySelectorAll("[data-calendar-selected-label]").forEach((node) => {
    node.textContent = pretty
  })

  const weekdayField = document.querySelector("[data-grade-weekday]")
  const cwday = String(button.dataset.cwday || "")
  if (weekdayField && weekdayField.querySelector(`option[value="${cwday}"]`)) {
    weekdayField.value = cwday
    weekdayField.dispatchEvent(new Event("change", { bubbles: true }))
  }
}

function selectedSlots() {
  const day = selectedButton()
  const tempos = parseJsonData("tempos", {})
  const cwday = day?.dataset.cwday
  const saved = tempos[cwday] || tempos[String(cwday)] || []
  if (saved.length) return saved

  const fromForm = formPeriod()
  return fromForm ? [fromForm] : []
}

function copyGradeIntoGenerateForm() {
  const period = document.querySelector("[data-grade-period]")?.value
  const course = document.querySelector("[data-grade-course]")?.value
  const periodField = document.querySelector("[data-generate-period]")
  const courseField = document.querySelector("[data-generate-course]")
  if (periodField) periodField.value = period || ""
  if (courseField) courseField.value = course || ""
}

function confirmPhrase(timeSlots) {
  const day = selectedButton()
  const weekdays = parseJsonData("weekdays", {})
  const cwday = day?.dataset.cwday
  const weekday = weekdays[cwday] || weekdays[String(cwday)] || "dia"
  const slots = timeSlots?.length ? timeSlots : selectedSlots()
  const slotText = slots.length ? slots.join(" e ") : "sem tempo na grade"
  const number = day?.dataset.bimester
  const bimester = number ? `${number}º bimestre` : "bimestre não definido"
  return `Deseja criar a aula ${weekday}, ${formatDate(selectedIso())}, ${slotText}, ${bimester}?`
}

function selectDay(button) {
  const root = schoolCalendarRoot()
  if (!root || !button) return

  const iso = button.dataset.date
  root.dataset.selectedDay = iso
  root.querySelectorAll("[data-calendar-day]").forEach((day) => {
    const on = day === button
    day.classList.toggle("is-selected", on)
    day.setAttribute("aria-pressed", on ? "true" : "false")
  })
  const nameField = document.querySelector("[data-calendar-name]")
  if (nameField) {
    nameField.value = button.dataset.name || ""
  }
  const kindField = document.querySelector("[data-calendar-kind]")
  if (kindField) {
    const kind = button.dataset.kind
    kindField.value = kindField.querySelector(`option[value="${kind}"]`) ? kind : "holiday"
  }
  syncTurmaBlock(button)
}

function confirmMonthHost() {
  return document.querySelector("[data-calendar-confirm-month]")
}

function monthArticle(number) {
  return schoolCalendarRoot()?.querySelector(`.year-month[data-month="${number}"]`)
}

function pdfConfirmCopy() {
  return `${confirmPhrase(["tempo do horário"])} Clique noutro dia neste calendário para mudar a data. O dia pintado é o que entra no diário.`
}

function refreshPdfConfirmCopy() {
  const confirmCopy = document.querySelector("[data-calendar-confirm-copy]")
  if (confirmCopy) confirmCopy.textContent = pdfConfirmCopy()
}

function paintConfirmMonth(confirmMonth = confirmMonthHost(), iso = selectedIso(), monthNumber = null) {
  const sourceDay = schoolCalendarRoot()?.querySelector(`[data-calendar-day][data-date="${iso}"]`)
  const month = monthNumber
    ? monthArticle(monthNumber)
    : sourceDay?.closest(".year-month")
  if (!confirmMonth || !month) return

  const shownMonth = Number(month.dataset.month)
  confirmMonth.innerHTML = ""

  const nav = document.createElement("div")
  nav.className = "calendar-confirm-month-nav"
  const prev = document.createElement("button")
  prev.type = "button"
  prev.className = "button button-ghost button-small"
  prev.dataset.confirmMonthStep = "-1"
  prev.textContent = "Mês anterior"
  prev.disabled = shownMonth <= 1
  const next = document.createElement("button")
  next.type = "button"
  next.className = "button button-ghost button-small"
  next.dataset.confirmMonthStep = "1"
  next.textContent = "Próximo mês"
  next.disabled = shownMonth >= 12
  nav.append(prev, next)

  const clone = month.cloneNode(true)
  clone.querySelectorAll("button").forEach((node) => {
    const on = node.dataset.date === iso
    node.disabled = false
    node.classList.toggle("is-painted", on)
    node.setAttribute("aria-pressed", on ? "true" : "false")
  })

  confirmMonth.append(nav, clone)
}

function shownConfirmMonthNumber() {
  return Number(confirmMonthHost()?.querySelector(".year-month")?.dataset.month)
}

function selectConfirmDay(previewButton) {
  const iso = previewButton.dataset.date
  const mainButton = schoolCalendarRoot()?.querySelector(`[data-calendar-day][data-date="${iso}"]`)
  if (!mainButton) return

  if (!isSchoolDay(mainButton)) {
    toast("error", "Este dia não é letivo.")
    return
  }

  selectDay(mainButton)
  paintConfirmMonth(confirmMonthHost(), iso, shownConfirmMonthNumber())
  refreshPdfConfirmCopy()
}

function toast(kind, message, extra = {}) {
  window.MaestroToast?.show({ kind, message, ...extra })
}

document.addEventListener("click", async (event) => {
  const confirmDay = event.target.closest("[data-calendar-confirm-month] [data-calendar-day]")
  if (confirmDay) {
    event.preventDefault()
    selectConfirmDay(confirmDay)
    return
  }

  const monthStep = event.target.closest("[data-confirm-month-step]")
  if (monthStep) {
    event.preventDefault()
    const nextMonth = shownConfirmMonthNumber() + Number(monthStep.dataset.confirmMonthStep)
    paintConfirmMonth(confirmMonthHost(), selectedIso(), nextMonth)
    return
  }

  const dayButton = event.target.closest("[data-calendar-day]")
  if (dayButton && schoolCalendarRoot()?.contains(dayButton)) {
    selectDay(dayButton)
    if (!isSchoolDay(dayButton)) {
      toast("error", "Este dia não é letivo.")
    }
    return
  }

  if (event.target.closest("[data-generate-open]")) {
    if (!isSchoolDay(selectedButton())) {
      toast("error", "Este dia não é letivo.")
      return
    }
    const slots = selectedSlots()
    if (!slots.length) {
      toast("error", "Informe o tempo da aula no campo Tempo.")
      return
    }
    copyGradeIntoGenerateForm()
    const copy = document.querySelector("[data-generate-confirm-copy]")
    if (copy) copy.textContent = confirmPhrase(slots)
    document.querySelector("[data-generate-confirm]")?.showModal()
    return
  }

  if (event.target.closest("[data-generate-cancel]")) {
    document.querySelector("[data-generate-confirm]")?.close()
    window.MaestroActionConfirm?.denied()
    return
  }

  if (event.target.closest("[data-calendar-confirm] button[value='cancel']")) {
    window.MaestroActionConfirm?.denied()
    return
  }

  if (event.target.closest("[data-calendar-pdf-open]")) {
    const fileInput = document.querySelector("[data-calendar-pdf-file]")
    const confirmDialog = document.querySelector("[data-calendar-confirm]")
    const confirmCopy = confirmDialog?.querySelector("[data-calendar-confirm-copy]")
    const confirmMonth = confirmDialog?.querySelector("[data-calendar-confirm-month]")

    if (!fileInput?.files[0]) {
      toast("error", "Anexe o PDF do horário da escola.")
      return
    }
    if (!selectedIso()) {
      toast("error", "Clique no dia da aula no calendário.")
      return
    }
    if (!isSchoolDay(selectedButton())) {
      toast("error", "Este dia não é letivo.")
      return
    }

    if (confirmCopy) confirmCopy.textContent = pdfConfirmCopy()
    paintConfirmMonth(confirmMonth)
    confirmDialog?.showModal()
    return
  }

  const createButton = event.target.closest("[data-calendar-confirm-create]")
  if (!createButton) return

  const openButton = document.querySelector("[data-calendar-pdf-open]")
  const fileInput = document.querySelector("[data-calendar-pdf-file]")
  const classroomId = document.querySelector("[name='classroom_id']")?.value
  const lessonDate = selectedIso()
  const file = fileInput?.files[0]
  if (!file || !classroomId || !lessonDate || !openButton) return

  const token = document.querySelector('meta[name="csrf-token"]')?.content
  const payload = new FormData()
  payload.append("timetable", file)
  payload.append("classroom_id", classroomId)
  payload.append("lesson_date", lessonDate)
  const courseId = document.getElementById("calendar_pdf_course_id")?.value
  if (courseId) payload.append("course_id", courseId)

  createButton.disabled = true
  try {
    const response = await fetch(openButton.dataset.timetableUrl, {
      method: "POST",
      headers: {
        Accept: "application/json",
        "X-CSRF-Token": token
      },
      body: payload
    })
    const data = await response.json()
    if (!response.ok || !data.ok) {
      toast("error", data.error || "Não foi possível criar a aula.")
      return
    }

    document.querySelector("[data-calendar-confirm]")?.close()
    toast(data.warning ? "attention" : "success", [data.message, data.warning].filter(Boolean).join(" "), {
      href: data.diary_url,
      action: "Abrir diário",
      duration: 0
    })
  } catch (_error) {
    toast("error", "Falha ao enviar o PDF.")
  } finally {
    createButton.disabled = false
  }
})

document.addEventListener("change", (event) => {
  const fileInput = event.target.closest("[data-calendar-pdf-file]")
  if (!fileInput) return
  const filename = document.querySelector("[data-calendar-pdf-filename]")
  if (filename) {
    filename.textContent = fileInput.files[0]?.name || "Nenhum arquivo anexado."
  }
})
