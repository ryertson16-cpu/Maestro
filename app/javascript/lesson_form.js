function initializeLessonForm() {
  const toggle = document.querySelector("[data-activity-toggle]")
  const fields = document.querySelector("[data-activity-fields]")

  if (toggle && fields) {
    function updateActivityVisibility() {
      fields.hidden = !toggle.checked
    }

    toggle.addEventListener("change", updateActivityVisibility)
    updateActivityVisibility()
  }

  initializeTimetableImport()
  initializeMyTimetableDate()
}

function initializeMyTimetableDate() {
  const dateField = document.getElementById("lesson_lesson_date")
  if (!dateField || dateField.dataset.myTimetableBound === "true") return
  dateField.dataset.myTimetableBound = "true"
  dateField.addEventListener("change", () => {
    const url = new URL(window.location.href)
    if (dateField.value) url.searchParams.set("lesson_date", dateField.value)
    const classroom = document.getElementById("lesson_classroom_id")?.value
    if (classroom) url.searchParams.set("classroom_id", classroom)
    window.location.assign(url.toString())
  })
}

function initializeTimetableImport() {
  const root = document.querySelector("[data-timetable-import]")
  if (!root || root.dataset.bound === "true") return
  root.dataset.bound = "true"

  const fileInput = root.querySelector("[data-timetable-file]")
  const generateButton = root.querySelector("[data-timetable-generate]")
  const filename = root.querySelector("[data-timetable-filename]")
  const status = root.querySelector("[data-timetable-status]")

  fileInput?.addEventListener("change", () => {
    const file = fileInput.files[0]
    if (filename) {
      filename.textContent = file ? file.name : "Nenhum arquivo anexado."
    }
    setStatus(status, "", "")
  })

  generateButton?.addEventListener("click", async () => {
    const file = fileInput?.files[0]
    if (!file) {
      setStatus(status, "Anexe o PDF do horário da escola.", "erro")
      return
    }

    const classroomId = document.getElementById("lesson_classroom_id")?.value
    const lessonDate = document.getElementById("lesson_lesson_date")?.value
    if (!classroomId || !lessonDate) {
      setStatus(status, "Selecione a turma e a data da aula antes de gerar.", "erro")
      return
    }

    const token = document.querySelector('meta[name="csrf-token"]')?.content
    const payload = new FormData()
    payload.append("timetable", file)
    payload.append("classroom_id", classroomId)
    payload.append("lesson_date", lessonDate)
    const courseId = document.getElementById("lesson_course_id")?.value
    if (courseId) payload.append("course_id", courseId)

    generateButton.disabled = true
    setStatus(status, "Lendo o horário e preenchendo a aula…", "")

    try {
      const response = await fetch(generateButton.dataset.timetableUrl, {
        method: "POST",
        headers: {
          Accept: "application/json",
          "X-CSRF-Token": token
        },
        body: payload
      })
      const data = await response.json()
      if (!response.ok || !data.ok) {
        setStatus(status, data.error || "Não foi possível gerar a aula.", "erro")
        return
      }

      fillLessonFields(data)
      const note = [data.message, data.warning].filter(Boolean).join(" ")
      setStatus(status, note, data.warning ? "aviso" : "ok")
    } catch (error) {
      setStatus(status, "Falha ao enviar o PDF.", "erro")
    } finally {
      generateButton.disabled = false
    }
  })
}

function fillLessonFields(data) {
  setField("lesson_classroom_id", data.classroom_id)
  setSelectValue("lesson_course_id", data.course_id, data.course_name)
  setField("lesson_theme", data.theme)
  setField("lesson_objective", data.objective)
  setField("lesson_content", data.content)
  setField("lesson_methodology", data.methodology)
  setSelectValue("lesson_siage_period", data.siage_period)
  setSelectValue("lesson_siage_class_mode", data.siage_class_mode)
  setSelectValue("lesson_siage_class_type", data.siage_class_type)
  setSelectValue("lesson_siage_time_slot", data.siage_time_slot)
}

function setSelectValue(id, value, label) {
  const field = document.getElementById(id)
  if (!field || value == null || value === "") return
  if (field.tagName !== "SELECT") {
    setField(id, value)
    return
  }
  const str = String(value)
  if (![...field.options].some((option) => option.value === str)) {
    const option = document.createElement("option")
    option.value = str
    option.textContent = label || str
    field.appendChild(option)
  }
  field.value = str
  field.dispatchEvent(new Event("change", { bubbles: true }))
}

function setField(id, value) {
  const field = document.getElementById(id)
  if (!field || value == null || value === "") return
  field.value = value
  field.dispatchEvent(new Event("change", { bubbles: true }))
  field.dispatchEvent(new Event("input", { bubbles: true }))
}

function setStatus(node, text, kind) {
  if (node) {
    node.hidden = true
    node.textContent = ""
  }
  if (!text) return

  const toastKind = { erro: "error", aviso: "attention", ok: "success" }[kind] || "attention"
  window.MaestroToast?.show({
    kind: toastKind,
    message: text
  })
}

document.addEventListener("turbo:load", initializeLessonForm)