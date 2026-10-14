class ProjectStagesController < ApplicationController
  before_action :authenticate_professor!
  before_action :set_project
  before_action :set_stage, only: %i[update destroy remove_evidence]

  def create
    position = @project.project_stages.maximum(:position).to_i + 1
    stage = @project.project_stages.new(stage_params.merge(position: position))

    if stage.save
      attach_evidences(stage)
      redirect_to @project, notice: "Etapa adicionada."
    else
      redirect_to @project, alert: stage.errors.full_messages.to_sentence
    end
  end

  def update
    if @stage.update(stage_params)
      attach_evidences(@stage)
      redirect_to @project, notice: "Etapa atualizada."
    else
      redirect_to @project, alert: @stage.errors.full_messages.to_sentence
    end
  end

  def destroy
    @stage.destroy
    redirect_to @project, notice: "Etapa removida."
  end

  def remove_evidence
    evidence = @stage.evidences.find(params[:evidence_id])
    evidence.purge_later
    redirect_to @project, notice: "Evidência removida."
  end

  private

  def set_project
    @project = current_professor.projects.find(params[:project_id])
  end

  def set_stage
    @stage = @project.project_stages.find(params[:id])
  end

  def stage_params
    permitted = params.require(:project_stage).permit(
      :title,
      :description,
      :due_on,
      :status,
      :lesson_id
    )
    permitted[:lesson_id] = nil if permitted[:lesson_id].blank?
    permitted
  end

  def attach_evidences(stage)
    files = Array(params.dig(:project_stage, :evidences)).reject(&:blank?)
    stage.evidences.attach(files) if files.any?
  end
end
