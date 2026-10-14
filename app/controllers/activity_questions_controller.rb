class ActivityQuestionsController < ApplicationController
  before_action :authenticate_professor!
  before_action :set_activity

  def create
    question = current_professor.questions.find(params[:question_id])
    Activities::Composer.new(@activity).add(question)
    redirect_to assemble_activity_path(@activity), notice: "Questão incluída na atividade."
  end

  def destroy
    item = @activity.activity_questions.find(params[:id])
    Activities::Composer.new(@activity).remove(item)
    redirect_to assemble_activity_path(@activity), notice: "Questão retirada da atividade."
  end

  def move
    item = @activity.activity_questions.find(params[:id])
    Activities::Composer.new(@activity).move(item, params[:direction])
    redirect_to assemble_activity_path(@activity)
  end

  private

  def set_activity
    @activity = Activity
      .joins(:lesson)
      .where(lessons: { classroom_id: current_professor.classrooms.select(:id) })
      .find(params[:activity_id])
  end
end
