class LessonPlanTemplatesController < ApplicationController
  before_action :authenticate_professor!
  before_action :set_template, only: %i[edit update destroy]

  def index
    @templates = current_professor.lesson_plan_templates.includes(:course).order(:title)
    @courses = current_professor.courses.active.order(:name)
  end

  def new
    @template = current_professor.lesson_plan_templates.new
    @courses = current_professor.courses.active.order(:name)
  end

  def create
    @template = current_professor.lesson_plan_templates.new(template_params)
    if @template.save
      redirect_to lesson_plan_templates_path, notice: "Plano salvo no banco."
    else
      @courses = current_professor.courses.active.order(:name)
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @courses = current_professor.courses.active.order(:name)
  end

  def update
    if @template.update(template_params)
      redirect_to lesson_plan_templates_path, notice: "Plano atualizado."
    else
      @courses = current_professor.courses.active.order(:name)
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @template.destroy
    redirect_to lesson_plan_templates_path, notice: "Plano removido."
  end

  private

  def set_template
    @template = current_professor.lesson_plan_templates.find(params[:id])
  end

  def template_params
    params.require(:lesson_plan_template).permit(
      :title,
      :course_id,
      :theme,
      :objective,
      :content,
      :methodology,
      :skills
    )
  end
end
