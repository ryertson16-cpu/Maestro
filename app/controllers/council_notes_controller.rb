class CouncilNotesController < ApplicationController
  before_action :authenticate_professor!
  before_action :set_context, except: :update

  def index
    @notes = CouncilNote
             .where(professor: current_professor, classroom: @classroom, bimester: @bimester)
             .includes(:student)
             .index_by(&:student_id)
    @students = Enrollment
                .where(professor: current_professor, classroom: @classroom, status: "active")
                .includes(:student)
                .joins(:student)
                .order("students.name")
                .map(&:student)
  end

  def generate
    students = Enrollment
               .where(professor: current_professor, classroom: @classroom, status: "active")
               .includes(:student)

    students.each do |enrollment|
      body = Council::NoteBuilder.new(
        professor: current_professor,
        classroom: @classroom,
        student: enrollment.student,
        bimester: @bimester
      ).body

      note = CouncilNote.find_or_initialize_by(
        professor: current_professor,
        classroom: @classroom,
        student: enrollment.student,
        bimester: @bimester
      )
      note.body = body
      note.generated_at = Time.current
      note.save!
    end

    redirect_to council_notes_path(classroom_id: @classroom.id, bimester: @bimester),
                notice: "Pareceres gerados. Revise antes do conselho."
  end

  def update
    note = current_professor.council_notes.find(params[:id])
    if note.update(body: params[:body])
      redirect_to council_notes_path(classroom_id: note.classroom_id, bimester: note.bimester),
                  notice: "Parecer atualizado."
    else
      redirect_to council_notes_path(classroom_id: note.classroom_id, bimester: note.bimester),
                  alert: note.errors.full_messages.to_sentence
    end
  end

  private

  def set_context
    @classrooms = current_professor.classrooms.order(:name)
    @classroom = resolve_classroom(fallback: true)
    @bimester = (1..4).cover?(params[:bimester].to_i) ? params[:bimester].to_i : Siage.bimester_for_date(Date.current)

    redirect_to classrooms_path, alert: "Cadastre uma turma para o conselho de classe." if @classroom.blank?
  end
end
