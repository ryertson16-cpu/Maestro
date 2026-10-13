class LessonsController < ApplicationController
  before_action :authenticate_professor!
  before_action :set_lesson,
                only: %i[show edit update destroy]

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
    classroom = current_professor.classrooms.find(params[:classroom_id])
    lesson_date = Date.parse(params[:lesson_date].to_s)
    file = params[:timetable]

    result = Lessons::TimetableLessonGenerator.new(
      professor: current_professor,
      classroom: classroom,
      lesson_date: lesson_date,
      upload: file,
      course: current_professor.courses.find_by(id: params[:course_id])
    ).call

    if result[:ok]
      persist_timetable_slots!(classroom, lesson_date, result)
      render json: result
    else
      render json: { ok: false, error: result[:error] },
             status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotFound
    render json: { ok: false, error: "Turma não encontrada." },
           status: :not_found
  rescue Date::Error
    render json: { ok: false, error: "Data da aula inválida." },
           status: :unprocessable_entity
  end

  private

  def persist_timetable_slots!(classroom, lesson_date, result)
    weekday = result[:weekday].to_i
    return unless (1..6).cover?(weekday)

    Array(result[:slots]).each do |slot|
      period = slot[:period].to_i
      next unless period.positive?

      entry = current_professor.timetable_entries.find_or_initialize_by(
        classroom: classroom,
        weekday: weekday,
        period: period
      )
      entry.course_id = result[:course_id]
      entry.time_slot = slot[:time_slot].presence || "#{period}º tempo"
      entry.save
    end
  end

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