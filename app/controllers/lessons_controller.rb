class LessonsController < ApplicationController
  before_action :authenticate_professor!
  before_action :set_lesson,
                only: %i[show edit update destroy copy]

  def index
    @classrooms = current_professor.classrooms.order(:name)

    @lessons = current_professor.lessons
                                .includes(:classroom, :course, :activity)
                                .order(lesson_date: :desc, created_at: :desc)

    if params[:classroom_id].present?
      @lessons = @lessons.where(
        classroom_id: params[:classroom_id]
      )
    end
  end

  def new
    @lesson = current_professor.lessons.new(
      lesson_date: lesson_date_from_params,
      classroom_id: params[:classroom_id].presence || remembered_classroom&.id
    )

    @classrooms = current_professor.classrooms.order(:name)
    @courses = current_professor.courses.active.order(:name)
    @plan_templates = current_professor.lesson_plan_templates.order(:title)
    apply_timetable_prefill(@lesson)
    @weekday_entries = weekday_entries_for(@lesson)
    @lesson.build_activity
  end

  def create
    @lesson = current_professor.lessons.new(lesson_params)

    classroom = current_professor.classrooms.find(
      lesson_params[:classroom_id]
    )

    @lesson.classroom = classroom

    if lesson_params[:lesson_plan_template_id].present?
      template = current_professor.lesson_plan_templates.find_by(id: lesson_params[:lesson_plan_template_id])
      template&.apply_to(@lesson)
    end

    if @lesson.has_activity?
      @lesson.build_activity unless @lesson.activity.present?
    else
      @lesson.activity = nil
    end

    if @lesson.save
      redirect_to attendance_records_path(
                    classroom_id: @lesson.classroom_id,
                    attendance_date: @lesson.lesson_date
                  ),
                  flash: {
                    maestro_recap: Maestro::ActionRecap.new(current_professor).lesson_saved(@lesson)
                  }
    else
      load_form_options
      @lesson.build_activity if @lesson.has_activity? &&
                                @lesson.activity.blank?

      render :new, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotFound
    @lesson.errors.add(
      :classroom,
      "não foi encontrada."
    )

    load_form_options
    render :new, status: :unprocessable_entity
  end

  def show
    @classrooms = current_professor.classrooms.order(:name)
  end

  def copy
    classroom = current_professor.classrooms.find(params[:classroom_id])
    lesson_date = Date.parse(params[:lesson_date].to_s)
    replica = Lessons::Copier.new(
      professor: current_professor,
      lesson: @lesson,
      classroom: classroom,
      lesson_date: lesson_date,
      copy_activities: params[:copy_activities].to_s != "0"
    ).call

    redirect_to lesson_path(replica),
                notice: "Aula copiada para #{classroom.name} em #{l(lesson_date)}."
  rescue Date::Error
    redirect_to lesson_path(@lesson), alert: "Informe uma data válida."
  rescue ActiveRecord::RecordNotFound
    redirect_to lesson_path(@lesson), alert: "Turma não encontrada."
  rescue ActiveRecord::RecordInvalid => error
    redirect_to lesson_path(@lesson),
                alert: error.record.errors.full_messages.to_sentence
  end

  def edit
    load_form_options
    @lesson.build_activity if @lesson.has_activity? &&
                              @lesson.activity.blank?
  end

  def update
    if lesson_params[:lesson_plan_template_id].present?
      template = current_professor.lesson_plan_templates.find_by(id: lesson_params[:lesson_plan_template_id])
      template&.apply_to(@lesson)
    end

    if @lesson.update(lesson_params)
      redirect_to attendance_records_path(
                    classroom_id: @lesson.classroom_id,
                    attendance_date: @lesson.lesson_date
                  ),
                  flash: {
                    maestro_recap: Maestro::ActionRecap.new(current_professor).lesson_saved(@lesson, updated: true)
                  }
    else
      load_form_options
      @lesson.build_activity if @lesson.has_activity? &&
                                @lesson.activity.blank?

      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    classroom_id = @lesson.classroom_id
    lesson_date = @lesson.lesson_date
    @lesson.destroy

    redirect_to after_destroy_path(classroom_id, lesson_date),
                notice: "Aula excluída com sucesso."
  end

  def generate_from_timetable
    lesson_date = Date.parse(params[:lesson_date].to_s)
    create_all = ActiveModel::Type::Boolean.new.cast(params[:create_all]) ||
                 params[:classroom_id].blank? ||
                 params[:timetable].present?

    day = Lessons::DayLessonsFromTimetable.new(
      professor: current_professor,
      lesson_date: lesson_date,
      upload: params[:timetable]
    ).call

    unless day[:ok]
      render json: { ok: false, error: day[:error] }, status: :unprocessable_entity
      return
    end

    if create_all
      render json: day.merge(redirect_url: lessons_path)
      return
    end

    classroom = current_professor.classrooms.find(params[:classroom_id])
    result = Lessons::TimetableLessonGenerator.new(
      professor: current_professor,
      classroom: classroom,
      lesson_date: lesson_date,
      upload: nil,
      course: current_professor.courses.find_by(id: params[:course_id])
    ).call

    payload = result[:ok] ? result : { ok: true }
    render json: payload.merge(message: [day[:message], payload[:message]].compact.join(" "))
  rescue ActiveRecord::RecordNotFound
    render json: { ok: false, error: "Turma não encontrada." },
           status: :not_found
  rescue Date::Error
    render json: { ok: false, error: "Data da aula inválida." },
           status: :unprocessable_entity
  end

  private

  def set_lesson
    @lesson = current_professor.lessons
                               .includes(:classroom, :course, :activity)
                               .find(params[:id])
  end

  def after_destroy_path(classroom_id, lesson_date)
    if params[:return_to] == "diary"
      attendance_records_path(
        classroom_id: classroom_id,
        attendance_date: lesson_date
      )
    else
      lessons_path(classroom_id: classroom_id)
    end
  end

  def load_form_options
    @classrooms = current_professor.classrooms.order(:name)
    @courses = current_professor.courses.active.order(:name)
    @plan_templates = current_professor.lesson_plan_templates.order(:title)
  end

  def apply_timetable_prefill(lesson)
    return if lesson.classroom_id.blank? || lesson.lesson_date.blank? || params[:period].blank?

    entry = current_professor.timetable_entries.find_by(
      classroom_id: lesson.classroom_id,
      weekday: lesson.lesson_date.cwday,
      period: params[:period].to_i
    )
    return unless entry

    lesson.course_id ||= entry.course_id
    lesson.siage_time_slot = entry.time_slot_label
    lesson.theme ||= "Aula de #{entry.course&.name || 'componente'}"
    template = matching_plan_template(lesson.course_id)
    template&.apply_to(lesson)
  end

  def matching_plan_template(course_id)
    return if course_id.blank?

    current_professor.lesson_plan_templates.where(course_id: course_id).order(updated_at: :desc).first ||
      current_professor.lesson_plan_templates.where(course_id: nil).order(updated_at: :desc).first
  end

  def weekday_entries_for(lesson)
    return TimetableEntry.none if lesson.lesson_date.blank?

    current_professor.timetable_entries
                     .joins(:classroom)
                     .includes(:classroom, :course)
                     .where(weekday: lesson.lesson_date.cwday)
                     .order("timetable_entries.period, classrooms.name")
  end

  def lesson_date_from_params
    return Date.current if params[:lesson_date].blank?

    Date.parse(params[:lesson_date].to_s)
  rescue Date::Error
    Date.current
  end

  def lesson_params
    params.require(:lesson).permit(
      :lesson_date,
      :theme,
      :classroom_id,
      :course_id,
      :content,
      :objective,
      :methodology,
      :skills,
      :siage_period,
      :siage_class_mode,
      :siage_class_type,
      :siage_time_slot,
      :lesson_plan_template_id,
      :has_activity,
      activity_attributes: [
        :id,
        :title,
        :activity_type,
        :maximum_score,
        :due_date,
        :description,
        :instructions,
        :_destroy
      ]
    )
  end
end