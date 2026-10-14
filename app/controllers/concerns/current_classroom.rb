module CurrentClassroom
  extend ActiveSupport::Concern

  CLASSROOM_MEMORY_KEY = :maestro_classroom_id

  included do
    helper_method :remembered_classroom
    after_action :persist_classroom_memory, if: :should_persist_classroom_memory?
  end

  def remembered_classroom
    return unless professor_signed_in?

    id = session[CLASSROOM_MEMORY_KEY].presence || cookies.signed[CLASSROOM_MEMORY_KEY]
    classroom = current_professor.classrooms.find_by(id: id) if id.present?
    classroom || default_classroom
  end

  def remember_current_classroom(classroom)
    return unless professor_signed_in?
    return unless classroom&.persisted?
    return unless classroom.professor_id == current_professor.id

    session[CLASSROOM_MEMORY_KEY] = classroom.id
    cookies.signed[CLASSROOM_MEMORY_KEY] = {
      value: classroom.id,
      expires: 1.year.from_now,
      httponly: true,
      same_site: :lax
    }
  end

  def resolve_classroom(fallback: true)
    if params[:classroom_id].present?
      classroom = current_professor.classrooms.find_by(id: params[:classroom_id])
      if classroom
        remember_current_classroom(classroom)
        return classroom
      end

      raise ActiveRecord::RecordNotFound unless fallback
    end

    return unless fallback

    classroom = remembered_classroom
    remember_current_classroom(classroom)
    classroom
  end

  private

  def default_classroom
    current_professor.classrooms.where(active: true).order(:name).first ||
      current_professor.classrooms.order(:name).first
  end

  def should_persist_classroom_memory?
    professor_signed_in? &&
      request.format.html? &&
      !devise_controller?
  end

  def persist_classroom_memory
    id = params[:classroom_id].presence
    id ||= params[:id] if controller_name == "classrooms" &&
                          action_name.in?(%w[show edit update])

    classroom = current_professor.classrooms.find_by(id: id) if id.present?
    classroom ||= @classroom if instance_variable_defined?(:@classroom)
    classroom ||= @selected_classroom if instance_variable_defined?(:@selected_classroom)

    remember_current_classroom(classroom)
  end
end
