class SchoolsController < ApplicationController
  before_action :authenticate_professor!
  before_action :set_school

  def edit
  end

  def update
    @school.assign_attributes(school_params)

    if @school.save
      redirect_to settings_path, notice: "Dados da escola atualizados."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def remove_crest
    @school.crest.purge_later if @school.persisted? && @school.crest.attached?
    redirect_to settings_path, notice: "Brasão removido."
  end

  private

  def set_school
    @school = current_professor.school || current_professor.build_school
  end

  def school_params
    params.require(:school).permit(:name, :regional, :regional_other, :crest)
  end
end
