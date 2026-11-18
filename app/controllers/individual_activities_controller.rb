class IndividualActivitiesController < ApplicationController
  before_action :authenticate_professor!

  def new
    @questions = selected_questions
    if @questions.empty?
      redirect_to questions_path, alert: "Selecione ao menos uma questão."
      return
    end

    @classrooms = current_professor.classrooms.where(active: true).order(:name)
    @classroom = @classrooms.find_by(id: params[:classroom_id]) || @classrooms.first
    @students = roster(@classroom)
  end

  def create
    questions = selected_questions
    classroom = current_professor.classrooms.where(active: true).find(params[:classroom_id])
    student = roster(classroom).find { |item| item.id == params[:student_id].to_i }
    if questions.empty? || student.nil?
      redirect_to questions_path, alert: "Escolha as questões, a turma e o aluno."
      return
    end

    activity = IndividualActivities::Builder.new(
      professor: current_professor,
      classroom: classroom,
      student: student,
      questions: questions
    ).create!

    redirect_to assemble_activity_path(activity),
                notice: "Atividade de #{student.name} criada em #{classroom.name}."
  rescue ActiveRecord::RecordNotFound
    redirect_to questions_path, alert: "Não encontrei essa turma."
  rescue ActiveRecord::RecordInvalid => error
    redirect_to questions_path, alert: error.record.errors.full_messages.to_sentence
  end

  private

  def selected_questions
    ids = Array(params[:question_ids]).map(&:to_i).uniq
    questions = current_professor.questions.where(id: ids).index_by(&:id)
    ids.filter_map { |id| questions[id] }
  end

  def roster(classroom)
    return [] if classroom.blank?

    classroom.students.merge(Enrollment.where(status: "active")).distinct.order(:name).to_a
  end
end
