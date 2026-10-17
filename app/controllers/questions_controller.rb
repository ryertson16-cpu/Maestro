class QuestionsController < ApplicationController
  before_action :authenticate_professor!
  before_action :set_question, only: %i[edit update destroy]

  def index
    @questions = current_professor
                 .questions
                 .includes(:course)
                 .search(params[:q])
                 .order(updated_at: :desc)
    @questions = @questions.where(kind: params[:kind]) if params[:kind].present?
    @questions = @questions.where(course_id: params[:course_id]) if params[:course_id].present?
    @courses = current_professor.courses.order(:name)
  end

  def new
    @question = current_professor.questions.build(kind: "objective", points: 1)
    load_form
  end

  def edit
    load_form
  end

  def create
    @question = current_professor.questions.build(question_params)
    if @question.save
      redirect_to questions_path, notice: "Questão salva no banco."
    else
      load_form
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @question.update(question_params)
      redirect_to questions_path, notice: "Questão atualizada."
    else
      load_form
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @question.destroy
    redirect_to questions_path, notice: "Questão removida do banco."
  end

  private

  def set_question
    @question = current_professor.questions.find(params[:id])
  end

  def load_form
    @courses = current_professor.courses.order(:name)
  end

  def question_params
    attrs = params.require(:question).permit(
      :prompt,
      :kind,
      :correct_letter,
      :points,
      :tag,
      :bncc_skill,
      :course_id,
      choice_texts: []
    )
    texts = Array(attrs.delete(:choice_texts))
    attrs[:choices] = Question.normalize_choices(Question::LETTERS, texts)
    attrs[:course_id] = current_professor.courses.where(id: attrs[:course_id]).pick(:id)
    attrs[:correct_letter] = nil if attrs[:kind].to_s == "discursive"
    attrs
  end
end
