class SiageExportsController < ApplicationController
  before_action :authenticate_professor!

  def help
  end

  def open
    @classroom = current_professor.classrooms.find_by(id: params[:classroom_id])
    @handoff = Siage::Handoff.payload(
      professor: current_professor,
      origin: request.base_url,
      classroom: @classroom
    )
    aulas = Array(@handoff.dig("job", "grupos")).sum { |grupo| Array(grupo["aulas"]).size }
    notas = Array(@handoff["grades"]).size

    @resumo = {
      aulas: aulas,
      notas: notas,
      cpf: current_professor.cpf.present?,
      senha: current_professor.siage_password.present?
    }
  end

  def lesson
    lesson = current_professor.lessons
                              .includes(:classroom, :course)
                              .find(params[:lesson_id])
    filename = "siage-aula-#{lesson.classroom.name.parameterize}-#{lesson.lesson_date}"

    record_shipment(
      classroom: lesson.classroom,
      kind: "lesson",
      lesson: lesson,
      filename: "#{filename}.json"
    )

    if request.format.json?
      send_payload(
        Siage::PayloadBuilder.for_lesson(lesson),
        filename
      )
    else
      send_spreadsheet(
        Siage::SpreadsheetBuilder.for_lesson(lesson, origin: request.base_url),
        filename
      )
    end
  end

  def attendance
    classroom = current_professor.classrooms.find(params[:classroom_id])
    date = Date.parse(params[:attendance_date].to_s)
    lesson = current_professor.lessons.find_by(classroom: classroom, lesson_date: date)
    filename = "siage-frequencia-#{classroom.name.parameterize}-#{date}"

    record_shipment(
      classroom: classroom,
      kind: "attendance",
      lesson: lesson,
      filename: "#{filename}.json"
    )

    send_payload(
      Siage::PayloadBuilder.for_attendance(
        professor: current_professor,
        classroom: classroom,
        date: date
      ),
      filename
    )
  rescue Date::Error
    redirect_back fallback_location: attendance_records_path,
                  alert: "Data inválida para exportar ao SIAGE."
  end

  def ledger
    classroom = current_professor.classrooms.find_by(id: params[:classroom_id])
    open_lessons = Siage::Ledger.new(professor: current_professor, classroom: classroom).open_lessons

    if open_lessons.empty?
      redirect_to siage_ledger_path({ classroom_id: classroom&.id }.compact),
                  alert: "Não há aulas pendentes para montar a planilha."
      return
    end

    filename = if classroom
      "siage-pendentes-#{classroom.name.parameterize}"
    else
      "siage-pendentes-todas-as-turmas"
    end

    open_lessons.each do |lesson|
      record_shipment(
        classroom: lesson.classroom,
        kind: "lesson",
        lesson: lesson,
        filename: "#{filename}.csv"
      )
    end

    send_spreadsheet(
      Siage::SpreadsheetBuilder.for_lessons(
        professor: current_professor,
        lessons: open_lessons,
        origin: request.base_url
      ),
      filename
    )
  end

  def classroom_lessons
    classroom = current_professor.classrooms.find(params[:classroom_id])
    filename = "siage-aulas-#{classroom.name.parameterize}"

    current_professor.lessons.where(classroom: classroom).find_each do |lesson|
      record_shipment(
        classroom: classroom,
        kind: "classroom_lessons",
        lesson: lesson,
        filename: "#{filename}.json"
      )
    end

    if request.format.json?
      send_payload(
        Siage::PayloadBuilder.for_classroom_lessons(
          professor: current_professor,
          classroom: classroom
        ),
        filename
      )
    else
      send_spreadsheet(
        Siage::SpreadsheetBuilder.for_classroom(
          professor: current_professor,
          classroom: classroom,
          origin: request.base_url
        ),
        filename
      )
    end
  end

  def grades
    classroom = current_professor.classrooms.find(params[:classroom_id])
    bimester = params[:bimester].to_i
    bimester = 3 unless (1..4).cover?(bimester)
    filename = "siage-notas-#{classroom.name.parameterize}-#{bimester}-bimestre"
    payload = Siage::PayloadBuilder.for_grades(
      professor: current_professor,
      classroom: classroom,
      bimester: bimester,
      origin: request.base_url
    )
    spreadsheet = grades_spreadsheet_request?

    record_shipment(
      classroom: classroom,
      kind: "grades",
      filename: "#{filename}.#{spreadsheet ? 'csv' : 'json'}",
      bimester: bimester
    )

    if spreadsheet
      send_spreadsheet(Siage::GradeSpreadsheet.csv(payload), filename)
    else
      send_payload(payload, filename)
    end
  end

  private

  def record_shipment(classroom:, kind:, lesson: nil, filename: nil, bimester: nil)
    SiageShipment.record!(
      professor: current_professor,
      classroom: classroom,
      kind: kind,
      lesson: lesson,
      filename: filename,
      bimester: bimester
    )
  end

  def send_spreadsheet(csv, filename)
    send_data csv,
              filename: "#{filename}.csv",
              type: "text/tab-separated-values; charset=utf-8",
              disposition: "attachment"
  end

  def grades_spreadsheet_request?
    request.format.csv? ||
      params[:format].to_s == "csv" ||
      params[:spreadsheet].present?
  end

  def send_payload(payload, filename)
    send_data JSON.pretty_generate(payload),
              filename: "#{filename}.json",
              type: "application/json",
              disposition: "attachment"
  end
end
