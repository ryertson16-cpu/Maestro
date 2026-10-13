class SchoolCoursesController < ApplicationController
  before_action :authenticate_professor!
  before_action :set_school_course,
                only: %i[
                  edit
                  update
                  destroy
                  edit_disciplines
                  update_disciplines
                ]

  def index
    @school_courses = current_professor
                      .school_courses
                      .includes(:courses)
                      .order(:name)
  end

  def new
    @school_course = current_professor
                     .school_courses
                     .new(active: true)
  end

  def create
    @school_course = current_professor
                     .school_courses
                     .new(school_course_params)

    if @school_course.save
      redirect_to courses_path,
                  notice: "Curso criado com sucesso."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @school_course.update(school_course_params)
      redirect_to courses_path,
                  notice: "Curso atualizado com sucesso."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @school_course.destroy
      redirect_to courses_path,
                  notice: "Curso removido com sucesso."
    else
      redirect_to courses_path,
                  alert: @school_course.errors.full_messages.to_sentence
    end
  end

  def edit_disciplines
    @available_courses = current_professor
                         .courses
                         .active
                         .order(:knowledge_area, :name)

    unless Course.technical_base_available_for?(current_professor)
      @available_courses = @available_courses.where.not(knowledge_area: "base_tecnica")
    end

    @selected_course_ids = @school_course
                           .course_disciplines
                           .pluck(:course_id)
  end

  def update_disciplines
    selected_ids = Array(params[:course_ids])
                   .reject(&:blank?)
                   .map(&:to_i)
                   .uniq

    valid_ids = current_professor
                .courses
                .where(id: selected_ids)
                .pluck(:id)

    CourseDiscipline.transaction do
      @school_course.course_disciplines.delete_all

      valid_ids.each_with_index do |course_id, index|
        @school_course.course_disciplines.create!(
          course_id: course_id,
          position: index,
          required: true
        )
      end
    end

    redirect_to courses_path,
                notice: "Disciplinas vinculadas ao curso com sucesso."
  rescue ActiveRecord::RecordInvalid => error
    redirect_to edit_disciplines_school_course_path(@school_course),
                alert: error.record.errors.full_messages.to_sentence
  end

  private

  def set_school_course
    @school_course = current_professor
                     .school_courses
                     .find(params[:id])
  end

  def school_course_params
    params.require(:school_course).permit(
      :name,
      :description,
      :active
    )
  end
end