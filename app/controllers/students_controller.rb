class StudentsController < ApplicationController
  before_action :authenticate_professor!
  before_action :set_student,
                only: %i[show report edit update destroy]

  def index
    @classrooms = current_professor
                  .classrooms
                  .includes(:grade_level)
                  .order(:name)

    @attendance_month = selected_attendance_month
    @month_dates = weekdays_in_month(@attendance_month)
    @search = params[:search].to_s.strip
    @total_student_count = current_professor.students.count

    @classroom_student_counts = Enrollment
                                .where(professor: current_professor, status: "active")
                                .group(:classroom_id)
                                .count

    @selected_classroom =
      if params[:classroom_id].present?
        current_professor.classrooms.find_by(id: params[:classroom_id])
      end

    @monthly_percentages = {}
    @attendance_records = {}

    if @selected_classroom
      @enrollments = Enrollment
        .where(
          professor: current_professor,
          classroom: @selected_classroom,
          status: "active"
        )
        .includes(:student)
        .joins(:student)
        .merge(filtered_students_scope)
        .order("students.name")

      @students = @enrollments.map(&:student)

      @attendance_records = AttendanceRecord
        .where(
          professor: current_professor,
          enrollment_id: @enrollments.map(&:id),
          attendance_date: Attendance::Frequency.month_range(@attendance_month)
        )
        .index_by do |record|
          [record.enrollment_id, record.attendance_date]
        end

      @enrollments.each do |enrollment|
        @monthly_percentages[enrollment.student_id] =
          monthly_percentage_for(enrollment)
      end
    else
      @enrollments = []
      @students = filtered_students_scope
                  .includes(enrollments: :classroom)
                  .order(:name)
    end
  end

  def show
    load_student_report_data
  end

  def report
    load_student_report_data

    pdf = Documents::StudentReport.new(
      professor: current_professor,
      student: @student,
      current_enrollments: @current_enrollments,
      current_classroom: @current_classroom,
      attendance_records: @attendance_records,
      activity_rows: @student_activity_rows,
      grade_history: @grade_history,
      council_note: @council_note,
      current_bimester: @current_bimester
    ).render

    send_data pdf,
              filename: "relatorio-#{normalized_filename(@student.name)}.pdf",
              type: "application/pdf",
              disposition: "attachment"
  end

  def new
    @student = current_professor.students.new(active: true)
    load_form_options
  end

  def create
    @student = current_professor.students.new(student_params)
    classroom_id = params.dig(:student, :classroom_id)

    Student.transaction do
      @student.save!

      if classroom_id.present?
        classroom = current_professor.classrooms.find(classroom_id)

        Enrollment.create!(
          professor: current_professor,
          student: @student,
          classroom: classroom,
          enrolled_on: Date.current,
          status: "active"
        )
      end
    end

    redirect_to students_path({ classroom_id: classroom_id }.compact),
                notice: "Aluno cadastrado com sucesso."
  rescue ActiveRecord::RecordInvalid => error
    @student = error.record if error.record.is_a?(Student)

    @student.errors.add(
      :base,
      error.record.errors.full_messages.to_sentence
    )

    load_form_options
    render :new, status: :unprocessable_entity
  rescue ActiveRecord::RecordNotFound
    @student.errors.add(
      :base,
      "A turma selecionada não foi encontrada."
    )

    load_form_options
    render :new, status: :unprocessable_entity
  end

  def edit
    load_form_options
  end

  def update
    if @student.update(student_params)
      redirect_to student_path(@student),
                  notice: "Aluno atualizado com sucesso."
    else
      load_form_options
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    name = @student.name
    classroom_id = @student.enrollments.find_by(status: "active")&.classroom_id

    @student.destroy_with_history!

    redirect_to after_destroy_path(classroom_id),
                notice: "#{name} foi excluído do cadastro."
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotDestroyed => error
    redirect_to student_path(@student),
                alert: error.record&.errors&.full_messages&.to_sentence.presence ||
                       "Não foi possível excluir o aluno."
  end

  private

  def set_student
    @student = current_professor.students.find(params[:id])
  end

  def after_destroy_path(classroom_id)
    return classroom_path(classroom_id) if classroom_id.present? &&
                                           current_professor.classrooms.exists?(classroom_id)

    students_path
  end

  def load_student_report_data
    @enrollments = @student.enrollments
                          .includes(
                            {
                              classroom: [
                                :school_course,
                                :course,
                                :grade_level
                              ]
                            },
                            :attendance_records
                          )
                          .order(enrolled_on: :desc)

    @current_enrollments = @enrollments.select do |enrollment|
      enrollment.status == "active"
    end

    @attendance_records = AttendanceRecord
      .where(
        professor: current_professor,
        enrollment_id: @enrollments.map(&:id)
      )
      .includes(:lesson, enrollment: :classroom)
      .order(attendance_date: :desc)

    @attendance_month = Date.current.beginning_of_month
    enrollment = @current_enrollments.first
    month_records =
      if enrollment
        @attendance_records.select do |record|
          record.enrollment_id == enrollment.id &&
            Attendance::Frequency.month_range(@attendance_month).cover?(record.attendance_date)
        end
      else
        []
      end
    month_snapshot = Attendance::Frequency.snapshot(month_records)
    @attendance_total = month_snapshot[:total]
    @attendance_present = month_snapshot[:present]
    @attendance_absent = month_snapshot[:absent]
    @attendance_justified = month_snapshot[:justified]
    @attendance_late = month_snapshot[:late]
    @attendance_percentage = month_snapshot[:percentage]

    classroom_ids = @enrollments.map(&:classroom_id).compact.uniq

    activities =
      if classroom_ids.any?
        Activity
          .joins(:lesson)
          .where(
            lessons: {
              classroom_id: classroom_ids,
              professor_id: current_professor.id
            }
          )
          .includes(
            :activity_submissions,
            :parent_activity,
            :activity_recipients,
            lesson: :course,
            adapted_versions: %i[activity_recipients activity_submissions]
          )
          .order(due_date: :desc, created_at: :desc)
      else
        Activity.none
      end

    @comparison_students_by_classroom_id =
      Enrollment
        .where(
          classroom_id: classroom_ids,
          status: "active"
        )
        .includes(:student)
        .group_by(&:classroom_id)
        .transform_values do |enrollments|
          enrollments
            .map(&:student)
            .compact
            .uniq
        end

    @student_activity_rows = activities.filter_map do |activity|
      next unless activity.assigned_to?(@student)

      submission =
        activity.activity_submissions.find do |item|
          item.student_id == @student.id
        end

      submitted_on = submission&.submitted_on
      due_date = activity.due_date

      status_key =
        if submitted_on.blank?
          "not_delivered"
        elsif due_date.present? && submitted_on > due_date
          "delivered_late"
        else
          "delivered"
        end

      status_label =
        case status_key
        when "delivered"
          "Entregue"
        when "delivered_late"
          "Entregue com atraso"
        else
          "Atividade Pendente"
        end

      {
        activity: activity,
        submission: submission,
        proposed_on: activity.created_at.to_date,
        due_date: due_date,
        submitted_on: submitted_on,
        status_key: status_key,
        status_label: status_label,
        bimester: activity.bimester,
        weight: activity.weight
      }
    end

    @pending_activity_rows = @student_activity_rows.select do |row|
      row[:status_key] == "not_delivered" &&
        row[:activity].required_delivery_for?(@student)
    end

    @current_classroom = @current_enrollments.first&.classroom
    @recovery_grades_by_student_and_bimester = RecoveryGrade
      .where(professor: current_professor, classroom_id: classroom_ids)
      .index_by { |item| [item.student_id, item.classroom_id, item.bimester] }
    @grade_history = build_grade_history(activities)
    @current_bimester = Siage.bimester_for_date(Date.current)
    if @current_classroom
      @council_note = CouncilNote.find_by(
        professor: current_professor,
        classroom: @current_classroom,
        student: @student,
        bimester: @current_bimester
      )
      enrollment = @current_enrollments.find { |item| item.classroom_id == @current_classroom.id }
      month = Date.current.beginning_of_month
      month_records = AttendanceRecord.where(
        professor: current_professor,
        enrollment: enrollment,
        attendance_date: month.all_month
      )
      @trajectory_alert = Monitoring::Trajectory.call(records: month_records, month: month)
    end
  end

  def build_grade_history(activities)
    activity_comparisons = activities.filter_map do |activity|
      classroom = activity.lesson.classroom
      students = comparison_students_for(classroom)

      submissions_by_student =
        activity.activity_submissions.index_by(&:student_id)

      scores = students.filter_map do |student|
        score = submissions_by_student[student.id]&.score

        score.present? ? score.to_f : nil
      end

      student_score =
        submissions_by_student[@student.id]&.score

      next if scores.empty? && student_score.blank?

      {
        activity_id: activity.id,
        title: activity.title.to_s,
        bimester: activity.bimester.to_i,
        score: student_score.present? ? student_score.to_f : nil,
        class_average: scores.any? ? (scores.sum.to_f / scores.size).round(2) : nil,
        due_date: activity.due_date&.strftime("%d/%m/%Y"),
        sort_date: (activity.due_date || activity.created_at.to_date)&.iso8601,
        discipline: activity_discipline_name(activity)
      }
    end

    bimester_comparisons = (1..4).map do |bimester|
      activities_by_bimester =
        activities.select do |activity|
          activity.bimester.to_i == bimester
        end

      student_averages = []
      class_averages = []

      activities_by_bimester
        .group_by { |activity| activity.lesson.classroom_id }
        .each do |_classroom_id, classroom_activities|

        classroom = classroom_activities.first.lesson.classroom
        students = comparison_students_for(classroom)

        student_average = Grades::BimesterScore.new(
          student: @student,
          activities: classroom_activities,
          recovery: recovery_for(@student, classroom, bimester)
        ).final_score

        class_student_averages = students.filter_map do |student|
          Grades::BimesterScore.new(
            student: student,
            activities: classroom_activities,
            recovery: recovery_for(student, classroom, bimester)
          ).final_score
        end

        student_averages << student_average if student_average.present?

        if class_student_averages.any?
          class_averages.concat(class_student_averages)
        end
      end

      student_average =
        if student_averages.any?
          (
            student_averages.sum.to_f / student_averages.size
          ).round(2)
        end

      class_average =
        if class_averages.any?
          (
            class_averages.sum.to_f / class_averages.size
          ).round(2)
        end

      {
        bimester: bimester,
        label: "#{bimester}º Bimestre",
        score: student_average,
        class_average: class_average
      }
    end

    {
      activities: activity_comparisons,
      bimesters: bimester_comparisons
    }
  end

  def comparison_students_for(classroom)
    students =
      @comparison_students_by_classroom_id[classroom.id] || []

    return students if students.any? do |student|
      student.id == @student.id
    end

    students + [@student]
  end

  def recovery_for(student, classroom, bimester)
    @recovery_grades_by_student_and_bimester&.[]([student.id, classroom.id, bimester])
  end

  def activity_discipline_name(activity)
    lesson = activity.lesson

    if lesson.respond_to?(:course) && lesson.course.present?
      lesson.course.name.to_s
    elsif lesson.respond_to?(:school_course) &&
          lesson.school_course.present?
      lesson.school_course.name.to_s
    else
      "Não informada"
    end
  end

  def draw_student_information(pdf)
    draw_section_title(pdf, "Informações do aluno")

    draw_student_photo(pdf)

    current_classrooms = @current_enrollments.map do |enrollment|
      enrollment.classroom.name
    end

    courses = @current_enrollments.map do |enrollment|
      classroom = enrollment.classroom

      classroom.school_course&.name ||
        classroom.course&.name
    end.compact.uniq

    information = [
      ["Nome", @student.name],
      [
        "Matrícula",
        @student.registration_number.presence || "Não informado"
      ],
      ["Série", @student.series.presence || "Não informada"],
      [
        "Turma",
        current_classrooms.any? ?
          current_classrooms.join(", ") :
          "Não matriculado em uma turma ativa"
      ],
      [
        "Curso",
        courses.any? ? courses.join(", ") : "Não informado"
      ],
      ["Status", @student.active? ? "Ativo" : "Inativo"]
    ]

    draw_two_column_table(pdf, information)
    pdf.move_down 16
  end

  def draw_attendance_summary(pdf)
    draw_section_title(pdf, "Resumo de frequência")

    percentage =
      @attendance_percentage.present? ?
        "#{@attendance_percentage}%" :
        "—"

    summary = [
      ["Frequência geral", percentage],
      ["Presenças", @attendance_present.to_s],
      ["Faltas", @attendance_absent.to_s],
      ["Justificadas", @attendance_justified.to_s],
      ["Atrasos", @attendance_late.to_s]
    ]

    draw_two_column_table(pdf, summary)
    pdf.move_down 16
  end

  def draw_enrollments_history(pdf)
    draw_section_title(pdf, "Histórico de turmas")

    if @enrollments.any?
      rows = [
        ["Turma", "Entrada", "Status"]
      ]

      @enrollments.each do |enrollment|
        rows << [
          enrollment.classroom.name,
          format_date(enrollment.enrolled_on),
          enrollment.status == "active" ? "Atual" : "Encerrada"
        ]
      end

      draw_data_table(pdf, rows, widths: [250, 120, 120])
    else
      pdf.text "Nenhuma turma encontrada."
    end

    pdf.move_down 16
  end

  def draw_attendance_history(pdf)
    draw_section_title(pdf, "Histórico de frequência")

    if @attendance_records.any?
      rows = [
        ["Data", "Turma", "Situação"]
      ]

      @attendance_records.each do |record|
        rows << [
          format_date(record.attendance_date),
          record.classroom&.name || "Não informado",
          attendance_status_label(record.status)
        ]
      end

      draw_data_table(pdf, rows, widths: [120, 250, 120])
    else
      pdf.text "Nenhum registro de frequência."
    end

    pdf.move_down 16
  end

  def draw_activities_history(pdf)
    draw_section_title(pdf, "Histórico de atividades")

    if @student_activity_rows.any?
      rows = [
        [
          "Atividade",
          "Disciplina",
          "Proposta",
          "Limite",
          "Entrega",
          "Nota",
          "Peso",
          "Status"
        ]
      ]

      @student_activity_rows.each do |row|
        activity = row[:activity]
        lesson = activity.lesson
        submission = row[:submission]

        discipline = activity_discipline_name(activity)

        score =
          if NumericScore.recorded?(submission&.score)
            format_score(submission.score)
          else
            "—"
          end

        rows << [
          activity.title.to_s,
          discipline,
          format_date(row[:proposed_on]),
          format_date(row[:due_date]),
          format_date(row[:submitted_on]),
          score,
          format_score(activity.weight),
          row[:status_label]
        ]
      end

      draw_data_table(
        pdf,
        rows,
        widths: [105, 75, 55, 55, 55, 42, 38, 80],
        font_size: 6
      )
    else
      pdf.text "Nenhuma atividade encontrada."
    end

    pdf.move_down 16
  end

  def draw_section_title(pdf, title)
    pdf.fill_color "1F4E79"
    pdf.text title, size: 13, style: :bold
    pdf.move_down 6
    pdf.fill_color "000000"
  end

  def draw_two_column_table(pdf, rows)
    pdf.table(
      rows,
      width: pdf.bounds.width,
      cell_style: {
        padding: [6, 8],
        borders: [:bottom],
        border_color: "D9E2F3",
        size: 9
      },
      column_widths: [150, pdf.bounds.width - 150]
    ) do |table|
      table.column(0).font_style = :bold
      table.column(0).text_color = "666666"
    end
  end

  def draw_data_table(pdf, rows, widths:, font_size: 8)
    table_width = widths.sum

    pdf.table(
      rows,
      width: table_width,
      column_widths: widths,
      header: true,
      row_colors: ["FFFFFF", "F4F7FA"],
      cell_style: {
        padding: [5, 5],
        size: font_size,
        borders: [:bottom],
        border_color: "D9E2F3",
        valign: :center
      }
    ) do |table|
      table.row(0).background_color = "1F4E79"
      table.row(0).text_color = "FFFFFF"
      table.row(0).font_style = :bold
    end
  end

  def draw_report_footer(pdf)
    pdf.number_pages(
      "Página <page> de <total>",
      at: [pdf.bounds.right - 100, 0],
      align: :right,
      size: 8,
      color: "777777"
    )
  end

  def attendance_status_label(status)
    case status
    when "present"
      "Presente"
    when "absent"
      "Ausente"
    when "justified"
      "Falta justificada"
    when "late"
      "Atrasado"
    else
      status.to_s.humanize
    end
  end

  def format_date(value)
    return "Não informada" if value.blank?

    I18n.l(value.to_date, format: "%d/%m/%Y")
  end

  def normalized_filename(value)
    value.to_s
         .parameterize(separator: "-")
         .presence || "aluno"
  end

  def student_params
    params.require(:student).permit(
      :name,
      :registration_number,
      :series,
      :active,
      :photo
    )
  end

  def load_form_options
    @classrooms = current_professor.classrooms.order(:name)
  end

  def filtered_students_scope
    scope = current_professor.students
    return scope if @search.blank?

    term = "%#{ActiveRecord::Base.sanitize_sql_like(@search.downcase)}%"
    scope.where(
      "LOWER(students.name) LIKE :q OR LOWER(COALESCE(students.registration_number, '')) LIKE :q",
      q: term
    )
  end

  def monthly_percentage_for(enrollment)
    records = @attendance_records.filter_map do |(enrollment_id, _date), record|
      record if enrollment_id == enrollment.id
    end

    Attendance::Frequency.percentage(records)
  end

  def selected_attendance_month
    if params[:month].present?
      Date.strptime(
        "#{params[:month]}-01",
        "%Y-%m-%d"
      ).beginning_of_month
    else
      Date.current.beginning_of_month
    end
  rescue Date::Error
    Date.current.beginning_of_month
  end

  def weekdays_in_month(month)
    first_day = month.beginning_of_month
    last_day = month.end_of_month

    (first_day..last_day).select do |date|
      date.monday? ||
        date.tuesday? ||
        date.wednesday? ||
        date.thursday? ||
        date.friday?
    end
  end
end
