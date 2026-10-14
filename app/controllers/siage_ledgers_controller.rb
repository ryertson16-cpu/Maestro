class SiageLedgersController < ApplicationController
  before_action :authenticate_professor!

  def index
    @classroom = current_professor.classrooms.find_by(id: params[:classroom_id])
    remember_current_classroom(@classroom)
    @ledger = Siage::Ledger.new(professor: current_professor, classroom: @classroom)
    @rows = @ledger.rows
    @summary = @ledger.summary
    @grade_rows = Siage::GradeLedger.new(professor: current_professor, classroom: @classroom).rows
    @classrooms = current_professor.classrooms.order(:name)
  end

  def grade_partial
    update_grade_status("partial", "Notas salvas parcialmente no SIAGE.")
  end

  def grade_launch
    update_grade_status("launched", "Notas lançadas no SIAGE.")
  end

  def grade_fail
    update_grade_status("failed", "Notas marcadas como falha no SIAGE.")
  end

  def verify
    update_status("verified", "Aula conferida no SIAGE.")
  end

  def fail
    update_status("failed", "Aula marcada como falha no SIAGE.")
  end

  private

  def update_status(status, notice)
    lesson = current_professor.lessons.find(params[:id])
    Siage::LedgerStatus.new(current_professor).apply_lesson(lesson, status)

    redirect_to siage_ledger_path(classroom_id: lesson.classroom_id), notice: notice
  end

  def update_grade_status(status, notice)
    classroom = current_professor.classrooms.find(params[:classroom_id])
    bimester = params[:bimester].to_i
    Siage::GradeStatus.new(current_professor).apply(
      classroom: classroom,
      bimester: bimester,
      status: status
    )

    redirect_to siage_ledger_path(classroom_id: classroom.id), notice: notice
  end
end
