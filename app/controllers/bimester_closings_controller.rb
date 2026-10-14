class BimesterClosingsController < ApplicationController
  before_action :authenticate_professor!
  before_action :set_context

  def show
    @report = Bimester::ClosingReport.new(
      professor: current_professor,
      classroom: @classroom,
      bimester: @bimester
    )
  end

  def close
    @report = Bimester::ClosingReport.new(
      professor: current_professor,
      classroom: @classroom,
      bimester: @bimester
    )

    if @report.blocking? && params[:force] != "1"
      redirect_to bimester_closing_path(classroom_id: @classroom.id, bimester: @bimester),
                  alert: "Ainda há pendências graves. Resolva ou confirme o fechamento mesmo assim."
      return
    end

    setting = @classroom.bimester_setting_for(@bimester)
    setting.minimum_score ||= 6.0
    setting.save!
    setting.close!

    redirect_to bimester_closing_path(classroom_id: @classroom.id, bimester: @bimester),
                notice: "Bimestre fechado."
  end

  private

  def set_context
    @classrooms = current_professor.classrooms.order(:name)
    @classroom = resolve_classroom(fallback: true)
    @bimester = (1..4).cover?(params[:bimester].to_i) ? params[:bimester].to_i : Siage.bimester_for_date(Date.current)

    redirect_to classrooms_path, alert: "Cadastre uma turma para fechar o bimestre." if @classroom.blank?
  end
end
