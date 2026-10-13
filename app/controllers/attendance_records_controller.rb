class AttendanceRecordsController < ApplicationController
  before_action :authenticate_professor!
  before_action :set_classroom, only: [:index, :save, :save_and_export]
  before_action :set_attendance_date, only: [:index, :save, :save_and_export]

  def index
    @classrooms = current_professor.classrooms.order(:name)
    @status_filter = params[:status].presence
    @siage_pending_count = Siage::Ledger.new(professor: current_professor).summary[:pending]

    return unless @classroom.present?

    load_diary
    @export_lesson = export_lesson_from_params
  end

  def save
    unless @classroom
      redirect_to attendance_records_path, alert: "Selecione uma turma."
      return
    end

    lesson = persist_diary!(exporting: false)

    redirect_to attendance_records_path(
      classroom_id: @classroom.id,
      attendance_date: @attendance_date
    ), flash: { maestro_recap: attendance_recap(lesson, exporting: false) }
  rescue ActiveRecord::RecordInvalid => error
    redirect_to attendance_records_path(
      classroom_id: @classroom&.id,
      attendance_date: @attendance_date
    ), alert: error.record.errors.full_messages.to_sentence
  end

  def save_and_export
    unless @classroom
      redirect_to attendance_records_path, alert: "Selecione uma turma."
      return
    end

    if params[:status].present?
      redirect_to attendance_records_path(
        classroom_id: @classroom.id,
        attendance_date: @attendance_date
      ), alert: "Mostre todos os alunos antes de baixar o JSON do SIAGE."
      return
    end

    lesson = persist_diary!(exporting: true)

    redirect_to attendance_records_path(
      classroom_id: @classroom.id,
      attendance_date: @attendance_date,
      export_lesson_id: lesson.id,
      lesson_id: lesson.id
    ), flash: { maestro_recap: attendance_recap(lesson, exporting: true) }
  rescue ActiveRecord::RecordInvalid => error
    redirect_to attendance_records_path(
      classroom_id: @classroom&.id,
      attendance_date: @attendance_date
    ), alert: error.record.errors.full_messages.to_sentence
  rescue ActiveRecord::RecordNotFound
    redirect_to attendance_records_path(
      classroom_id: @classroom&.id,
      attendance_date: @attendance_date
    ), alert: "Não foi possível salvar a aula desta turma."
  end

  def save_cell
    classroom = current_professor.classrooms.find(params[:classroom_id])

    enrollment = Enrollment.find_by!(
      id: params[:enrollment_id],
      professor: current_professor,
      classroom: classroom,
      status: "active"
    )

    attendance_date = Date.parse(params[:attendance_date].to_s)
    status = params[:status].to_s

    allowed_statuses = %w[present absent justified late]

    unless allowed_statuses.include?(status)
      render json: {
        success: false,
        error: "Status de frequência inválido."
      }, status: :unprocessable_entity

      return
    end

    records = AttendanceRecord.where(
      professor: current_professor,
      enrollment: enrollment,
      attendance_date: attendance_date
    )

    if records.any?
      records.each do |record|
        record.status = status
        record.save!
      end
      record = records.first
    else
      record = AttendanceRecord.create!(
        professor: current_professor,
        enrollment: enrollment,
        attendance_date: attendance_date,
        status: status
      )
    end

    month_dates = weekdays_in_month(attendance_date.beginning_of_month)

    month_records = AttendanceRecord.where(
      professor: current_professor,
      enrollment: enrollment,
      attendance_date: month_dates
    )

    total = month_records.count
    absences = month_records.where(status: "absent").count

    percentage =
      if total.zero?
        0
      else
        ((total - absences).to_f / total * 100).round(1)
      end

    render json: {
      success: true,
      status: record.status,
      percentage: percentage
    }
  rescue ActiveRecord::RecordNotFound
    render json: {
      success: false,
      error: "Aluno ou turma não encontrado."
    }, status: :not_found
  rescue Date::Error
    render json: {
      success: false,
      error: "Data inválida."
    }, status: :unprocessable_entity
  rescue ActiveRecord::RecordInvalid => error
    render json: {
      success: false,
      error: error.record.errors.full_messages.to_sentence
    }, status: :unprocessable_entity
  end

  private

  def load_diary
    all_enrollments = Enrollment
      .where(
        professor: current_professor,
        classroom: @classroom
      )
      .includes(:student)
      .joins(:student)
      .order("students.name")

    @lessons = sort_diary_lessons(
      current_professor.lessons
                       .where(classroom: @classroom, lesson_date: @attendance_date)
                       .includes(:course, :activity)
    )

    @classroom_lessons = current_professor.lessons
                                          .where(classroom: @classroom)
                                          .includes(:course, :activity)
                                          .order(lesson_date: :desc, created_at: :desc)

    @courses = current_professor.courses.active.order(:name)
    @plan_templates = current_professor.lesson_plan_templates.order(:title)
    @diary_lessons = @lessons.presence || [build_diary_lesson]
    @lesson = selected_diary_lesson

    all_day_records = AttendanceRecord.where(
      professor: current_professor,
      enrollment: all_enrollments,
      attendance_date: @attendance_date
    )
    @attendance_by_lesson = {}
    @diary_lessons.each_with_index do |lesson, index|
      key = diary_slot_key(lesson)
      scoped = if lesson.persisted?
                 all_day_records.select { |record| record.lesson_id == lesson.id }
               else
                 []
               end
      if scoped.blank? && index.zero?
        scoped = all_day_records.select { |record| record.lesson_id.blank? }
      end
      @attendance_by_lesson[key] = scoped.index_by(&:enrollment_id)
    end

    @all_enrollments = all_enrollments
    @summaries_by_lesson = {}
    @diary_lessons.each do |lesson|
      key = diary_slot_key(lesson)
      @summaries_by_lesson[key] = build_attendance_summary(
        all_enrollments,
        @attendance_by_lesson[key] || {}
      )
    end

    @attendance_records = @attendance_by_lesson[diary_slot_key(@lesson)] || {}
    @attendance_summary = build_attendance_summary(all_enrollments, @attendance_records)

    @enrollments =
      if @status_filter.present?
        all_enrollments.select do |enrollment|
          record = @attendance_records[enrollment.id]
          record&.status == @status_filter
        end
      else
        all_enrollments
      end
  end

  def build_diary_lesson
    current_professor.lessons.new(
      classroom: @classroom,
      lesson_date: @attendance_date,
      course: default_course,
      siage_period: Siage.period_for_date(@attendance_date),
      siage_class_mode: "Aula",
      siage_class_type: "Avulso",
      siage_time_slot: "1º tempo"
    )
  end

  def default_course
    @classroom.course.presence ||
      current_professor.lessons.where(classroom: @classroom).where.not(course_id: nil).order(lesson_date: :desc).first&.course ||
      @courses.first
  end

  def persist_diary!(exporting:)
    if params[:lessons].present?
      saved = persist_lesson_slots!(required: exporting)
      export_id = params[:export_lesson_id].presence
      saved.find { |lesson| lesson.id.to_s == export_id.to_s } || saved.first
    else
      lesson = upsert_diary_lesson!(required: exporting)
      persist_attendance!(lesson)
      lesson
    end
  end

  def persist_lesson_slots!(required:)
    saved = []
    params[:lessons].each do |slot_key, raw_attrs|
      attrs = raw_attrs.permit(
        :id, :course_id, :theme, :content, :objective, :methodology,
        :siage_period, :siage_class_mode, :siage_class_type,
        :siage_time_slot, :lesson_plan_template_id
      )
      exporting_this = required && (
        params[:export_lesson_id].blank? ||
          params[:export_lesson_id].to_s == attrs[:id].to_s ||
          params[:export_lesson_id].to_s == slot_key.to_s
      )
      lesson = upsert_diary_lesson!(required: exporting_this, attrs: attrs)
      persist_attendance!(
        lesson,
        params.dig(:attendance, slot_key) ||
          params.dig(:attendance, lesson.id.to_s) ||
          {}
      )
      saved << lesson
    end
    saved
  end

  def upsert_diary_lesson!(required:, attrs: nil)
    attrs ||= diary_lesson_params
    lesson = diary_lesson_record(attrs[:id], attrs[:siage_time_slot])

    if required && attrs[:course_id].blank? && lesson.course_id.blank?
      lesson.errors.add(:course, "selecione a disciplina para exportar ao SIAGE")
      raise ActiveRecord::RecordInvalid, lesson
    end

    skip_new_lesson = lesson.new_record? && !required &&
      attrs.values_at(:course_id, :theme, :siage_time_slot).all?(&:blank?)
    return lesson if skip_new_lesson

    lesson.assign_attributes(attrs.except(:id))
    if attrs[:lesson_plan_template_id].present?
      template = current_professor.lesson_plan_templates.find_by(id: attrs[:lesson_plan_template_id])
      template&.apply_to(lesson)
    end
    lesson.classroom = @classroom
    lesson.lesson_date = @attendance_date
    lesson.siage_period = lesson.siage_period.presence || Siage.period_for_date(@attendance_date)
    lesson.siage_class_mode = lesson.siage_class_mode.presence || "Aula"
    lesson.siage_class_type = lesson.siage_class_type.presence || "Avulso"
    lesson.siage_time_slot = lesson.siage_time_slot.presence || "1º tempo"
    lesson.theme = lesson.theme.presence || default_theme_for(lesson)
    lesson.save!
    lesson
  end

  def diary_lesson_record(id, time_slot = nil)
    if id.present?
      current_professor.lessons.find(id)
    else
      current_professor.lessons.find_or_initialize_by(
        classroom: @classroom,
        lesson_date: @attendance_date,
        siage_time_slot: time_slot.presence || "1º tempo"
      )
    end
  end

  def default_theme_for(lesson)
    course_name = lesson.course&.name.presence ||
      current_professor.courses.find_by(id: lesson.course_id)&.name ||
      "Componente curricular"
    "Aula de #{course_name}"
  end

  def attendance_recap(lesson, exporting:)
    Maestro::ActionRecap.new(current_professor).attendance(
      lesson: lesson,
      classroom: @classroom,
      exporting: exporting
    )
  end

  def diary_lesson_params
    params.fetch(:lesson, {}).permit(
      :id,
      :course_id,
      :theme,
      :content,
      :objective,
      :methodology,
      :siage_period,
      :siage_class_mode,
      :siage_class_type,
      :siage_time_slot,
      :lesson_plan_template_id
    )
  end

  def persist_attendance!(lesson, attendance_params = nil)
    attendance_params = params.fetch(:attendance, {}) if attendance_params.nil?

    enrollments = Enrollment.where(
      professor: current_professor,
      classroom: @classroom
    )

    AttendanceRecord.transaction do
      enrollments.each do |enrollment|
        values = attendance_params[enrollment.id.to_s]
        lookup = {
          professor: current_professor,
          enrollment: enrollment,
          attendance_date: @attendance_date
        }
        lookup[:lesson_id] = lesson.id if lesson&.persisted?

        record = AttendanceRecord.find_or_initialize_by(lookup)

        if values
          record.status = values[:status]
          record.notes = values[:notes]
        elsif record.new_record?
          record.status = "present"
        end

        record.lesson = lesson if lesson&.persisted?
        record.save!
      end
    end
  end

  def export_lesson_from_params
    return if params[:export_lesson_id].blank?

    current_professor.lessons.find_by(id: params[:export_lesson_id])
  end

  def build_attendance_summary(enrollments, attendance_records)
    summary = {
      total: enrollments.size,
      present: 0,
      absent: 0,
      justified: 0,
      late: 0,
      pending: 0
    }

    enrollments.each do |enrollment|
      record = attendance_records[enrollment.id]

      if record.present?
        status = record.status.to_sym
        summary[status] += 1 if summary.key?(status)
      else
        summary[:present] += 1
      end
    end

    summary
  end

  def set_classroom
    @classroom = resolve_classroom(fallback: true)
  rescue ActiveRecord::RecordNotFound
    redirect_to attendance_records_path,
                alert: "Turma não encontrada."
  end

  def set_attendance_date
    @attendance_date =
      if params[:attendance_date].present?
        Date.parse(params[:attendance_date].to_s)
      else
        Date.current
      end
  rescue Date::Error
    redirect_to attendance_records_path,
                alert: "Data inválida."
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

  def sort_diary_lessons(lessons)
    lessons.sort_by do |lesson|
      [slot_number(lesson.siage_time_slot), lesson.id.to_i]
    end
  end

  def slot_number(slot)
    slot.to_s.scan(/\d+/).first.to_i
  end

  def diary_slot_key(lesson)
    lesson.persisted? ? lesson.id : "new"
  end

  def selected_diary_lesson
    if params[:lesson_id].present?
      match = @diary_lessons.find { |lesson| lesson.id.to_s == params[:lesson_id].to_s }
      return match if match
    end

    @diary_lessons.first
  end
end
