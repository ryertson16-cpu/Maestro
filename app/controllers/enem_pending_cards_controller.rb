class EnemPendingCardsController < ApplicationController
  before_action :authenticate_professor!
  before_action :set_pending

  def assign
    student = @simulado.students_in_caderno.find_by(id: params[:student_id])
    unless student
      redirect_to enem_simulado_path(@simulado), alert: "Escolha o aluno deste PDF na lista."
      return
    end

    Enem::CardIntake.new(@simulado).assign_pending!(@pending, student)
    redirect_to enem_simulado_path(@simulado),
                notice: "Cartão de #{student.name} ligado. A nota ainda não foi lançada."
  end

  def destroy
    filename = @pending.filename
    @pending.destroy!
    redirect_to enem_simulado_path(@simulado), notice: "#{filename} saiu da lista de PDFs pendentes."
  end

  private

  def set_pending
    @simulado = current_professor.enem_simulados.find(params[:enem_simulado_id])
    @pending = @simulado.pending_cards.find(params[:id])
  end
end
