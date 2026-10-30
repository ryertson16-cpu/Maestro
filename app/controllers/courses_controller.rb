class CoursesController < ApplicationController
  before_action :authenticate_professor!
  before_action :set_course, only: %i[show edit update destroy]

  def index
    @available_knowledge_areas = Course.available_knowledge_areas_for(current_professor)
    @technical_base_available = Course.technical_base_available_for?(current_professor)

    @courses = current_professor.courses.order(:name)

    @school_courses = current_professor
                      .school_courses
                      .includes(:courses)
                      .order(:name)

    @grade_levels = current_professor
                    .grade_levels
                    .order(:name)
  end

  def show
  end

  def area
    knowledge_area = params[:knowledge_area].to_s

    unless Course.knowledge_area_names.key?(knowledge_area)
      redirect_to courses_path,
                  alert: "Área do conhecimento inválida."
      return
    end

    if knowledge_area == "base_tecnica" && !Course.technical_base_available_for?(current_professor)
      redirect_to courses_path,
                  alert: "A área Base Técnica só aparece quando um nível de ensino ativo tem técnico ou técnica no nome."
      return
    end

    @knowledge_area_key = knowledge_area
    @knowledge_area_name = Course.knowledge_area_names.fetch(knowledge_area)
    @knowledge_area_color =
      Course::KNOWLEDGE_AREA_COLORS.fetch(knowledge_area)

    @courses = current_professor.courses
                                .where(knowledge_area: knowledge_area)
                                .order(:name)
  end

  def new
    @course = current_professor.courses.new(
      active: true,
      knowledge_area: default_knowledge_area
    )
    @available_knowledge_areas = Course.available_knowledge_areas_for(current_professor)
  end

  def create
    @course = current_professor.courses.new(course_params)

    if @course.save
      redirect_to courses_path,
                  notice: "Disciplina criada com sucesso."
    else
      @available_knowledge_areas = Course.available_knowledge_areas_for(current_professor)
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @available_knowledge_areas = Course.available_knowledge_areas_for(current_professor)
    if @course.knowledge_area == "base_tecnica"
      @available_knowledge_areas = Course.knowledge_area_names
    end
  end

  def update
    if @course.update(course_params)
      redirect_to courses_path,
                  notice: "Disciplina atualizada com sucesso."
    else
      @available_knowledge_areas = Course.available_knowledge_areas_for(current_professor)
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @course.destroy
      redirect_to courses_path,
                  notice: "Disciplina removida com sucesso."
    else
      redirect_to courses_path,
                  alert: @course.errors.full_messages.to_sentence
    end
  end

  def catalog
    @technical_base_available = Course.technical_base_available_for?(current_professor)
    @grouped_catalog = Courses::Catalog.grouped(
      include_technical_base: @technical_base_available
    )
    @existing_keys = current_professor.courses.map do |course|
      "#{course.knowledge_area}::#{course.name}"
    end
  end

  def import_catalog
    created = Courses::CatalogImporter.new(
      professor: current_professor,
      keys: params[:catalog_keys]
    ).call

    if created.positive?
      message =
        if created == 1
          "1 disciplina adicionada ao seu catálogo."
        else
          "#{created} disciplinas adicionadas ao seu catálogo."
        end
      redirect_to courses_path, notice: message
    else
      redirect_to catalog_courses_path,
                  alert: "Nenhuma disciplina nova foi adicionada."
    end
  end

  private

  def set_course
    @course = current_professor.courses.find(params[:id])
  end

  def course_params
    permitted = params.require(:course).permit(
      :name,
      :description,
      :active,
      :knowledge_area
    )

    allowed = Course.available_knowledge_areas_for(current_professor).keys
    allowed |= ["base_tecnica"] if @course&.knowledge_area == "base_tecnica"
    permitted[:knowledge_area] = allowed.first unless allowed.include?(permitted[:knowledge_area])
    permitted
  end

  def default_knowledge_area
    Course.available_knowledge_areas_for(current_professor).keys.first || "matematica"
  end
end