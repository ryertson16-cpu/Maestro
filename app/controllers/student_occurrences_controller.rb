class StudentOccurrencesController < ApplicationController
  before_action :authenticate_professor!
  before_action :set_student

  def create
    occurrence = @student.student_occurrences.new(occurrence_params)
    occurrence.professor = current_professor
    occurrence.classroom = scoped_classroom(occurrence.classroom_id)

    if occurrence.save
      redirect_to student_path(@student), notice: "Ocorrência registrada."
    else
      redirect_to student_path(@student),
                  alert: occurrence.errors.full_messages.to_sentence
    end
  end

  def destroy
    occurrence = @student.student_occurrences.find(params[:id])
    occurrence.destroy
    redirect_to student_path(@student), notice: "Ocorrência removida."
  end

  private

  def set_student
    @student = current_professor.students.find(params[:student_id])
  end

  def scoped_classroom(id)
    return if id.blank?

    current_professor.classrooms.find_by(id: id)
  end

  def occurrence_params
    params.require(:student_occurrence).permit(:occurred_on, :kind, :body, :classroom_id)
  end
end
