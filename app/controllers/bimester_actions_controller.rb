class BimesterActionsController < ApplicationController
  before_action :authenticate_professor!

  def create
    grade_level = current_professor.grade_levels.find(params[:grade_level_id])
    bimester = (1..4).cover?(params[:bimester].to_i) ? params[:bimester].to_i : Siage.bimester_for_date(Date.current)

    action = current_professor.bimester_actions.new(action_params)
    action.grade_level = grade_level
    action.bimester = bimester
    action.position = BimesterAction.next_position_for(
      professor: current_professor,
      grade_level: grade_level,
      bimester: bimester
    )

    if action.save
      redirect_to monitoring_path(grade_level_id: grade_level.id, bimester: bimester),
                  notice: "Ação adicionada ao plano do bimestre."
    else
      redirect_to monitoring_path(grade_level_id: grade_level.id, bimester: bimester),
                  alert: action.errors.full_messages.to_sentence
    end
  rescue ActiveRecord::RecordNotFound
    redirect_to monitoring_path, alert: "Nível de ensino não encontrado."
  end

  def destroy
    action = current_professor.bimester_actions.find(params[:id])
    grade_level_id = action.grade_level_id
    bimester = action.bimester
    action.destroy!

    redirect_to monitoring_path(grade_level_id: grade_level_id, bimester: bimester),
                notice: "Ação removida do plano."
  rescue ActiveRecord::RecordNotFound
    redirect_to monitoring_path, alert: "Essa ação não está no seu caderno."
  end

  private

  def action_params
    params.require(:bimester_action).permit(:title, :audience, :due_on)
  end
end
