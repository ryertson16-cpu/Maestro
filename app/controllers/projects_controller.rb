class ProjectsController < ApplicationController
  before_action :authenticate_professor!
  before_action :set_project, only: %i[show edit update destroy report]

  def index
    @projects = current_professor.projects.includes(:classrooms, :project_stages).order(updated_at: :desc)
    @kind_filter = params[:kind].presence
    @status_filter = params[:status].presence
    @projects = @projects.where(kind: @kind_filter) if @kind_filter
    @projects = @projects.where(status: @status_filter) if @status_filter
    if params[:classroom_id].present?
      classroom = current_professor.classrooms.find_by(id: params[:classroom_id])
      @projects = @projects.joins(:project_classrooms).where(project_classrooms: { classroom_id: classroom.id }).distinct if classroom
    end
    @overdue_count = Project.overdue_for(current_professor).count
  end

  def show
    lesson_scope = current_professor.lessons.order(lesson_date: :desc)
    lesson_scope = lesson_scope.where(classroom: @project.classrooms) if @project.classrooms.any?
    @lessons = lesson_scope.limit(40)
    @students = @project.students
  end

  def new
    @project = current_professor.projects.new(
      status: "draft",
      kind: params[:kind].presence || "classroom",
      audience: default_audience_for(params[:kind])
    )
    load_form_options
  end

  def create
    @project = current_professor.projects.new(project_params)
    @project.classroom_ids = selected_classroom_ids

    if @project.save
      redirect_to @project, notice: "Projeto criado. Ajuste as etapas e anexe evidências."
    else
      load_form_options
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    load_form_options
  end

  def update
    @project.assign_attributes(project_params)
    @project.classroom_ids = selected_classroom_ids

    if @project.save
      redirect_to @project, notice: "Projeto atualizado."
    else
      load_form_options
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @project.destroy
    redirect_to projects_path, notice: "Projeto excluído."
  end

  def report
    letterhead = Documents::Letterhead.new(current_professor)
    pdf = build_report_pdf(letterhead)
    send_data pdf.render,
              filename: "projeto-#{@project.title.parameterize.presence || @project.id}.pdf",
              type: "application/pdf",
              disposition: "attachment"
  ensure
    letterhead&.cleanup
  end

  private

  def set_project
    @project = current_professor.projects
                                .includes(:classrooms, project_stages: :lesson)
                                .find(params[:id])
  end

  def load_form_options
    @classrooms = current_professor.classrooms.order(:name)
  end

  def default_audience_for(kind)
    case kind.to_s
    when "professor_nota_10" then "professor"
    when "school_nota_10" then "school"
    else "one_classroom"
    end
  end

  def selected_classroom_ids
    Array(params.dig(:project, :classroom_ids)).reject(&:blank?)
  end

  def project_params
    params.require(:project).permit(
      :title,
      :kind,
      :kind_other,
      :audience,
      :status,
      :starts_on,
      :ends_on,
      :objective,
      :justification,
      :skills,
      :team_notes
    )
  end

  def build_report_pdf(letterhead)
    Prawn::Document.new(page_size: "A4", page_layout: :portrait, margin: 36) do |pdf|
      letterhead.draw(
        pdf,
        title: @project.kind_label.upcase,
        subtitle: @project.title
      )

      pdf.fill_color "20263D"
      pdf.text "Situação: #{@project.status_label}", size: 10
      pdf.text "Alcance: #{@project.audience_label}", size: 10
      if @project.classrooms.any?
        pdf.text "Turmas: #{@project.classrooms.map(&:name).join(', ')}", size: 10
      end
      if @project.starts_on.present? || @project.ends_on.present?
        period = [@project.starts_on, @project.ends_on].compact.map { |day| I18n.l(day) }.join(" a ")
        pdf.text "Período: #{period}", size: 10
      end

      pdf.move_down 12
      draw_block(pdf, "Objetivo", @project.objective)
      draw_block(pdf, "Justificativa", @project.justification)
      draw_block(pdf, "Habilidades", @project.skills)
      draw_block(pdf, "Equipe e parceiros", @project.team_notes)

      pdf.move_down 8
      pdf.fill_color "5B4BDB"
      pdf.text "Etapas", size: 13, style: :bold
      pdf.move_down 8
      pdf.fill_color "20263D"

      @project.project_stages.each do |stage|
        pdf.text "#{stage.position}. #{stage.title} — #{stage.status_label}", size: 11, style: :bold
        pdf.text stage.description.to_s, size: 9 if stage.description.present?
        if stage.due_on.present?
          pdf.text "Prazo: #{I18n.l(stage.due_on)}", size: 9
        end
        if stage.lesson.present?
          pdf.text "Aula vinculada: #{I18n.l(stage.lesson.lesson_date)} · #{stage.lesson.theme}", size: 9
        end
        if stage.evidences.attached?
          pdf.text "#{stage.evidences.size} evidência(s) anexada(s).", size: 9
        end
        pdf.move_down 8
      end
    end
  end

  def draw_block(pdf, title, body)
    return if body.blank?

    pdf.fill_color "5B4BDB"
    pdf.text title, size: 11, style: :bold
    pdf.fill_color "20263D"
    pdf.text body, size: 10
    pdf.move_down 8
  end
end
