module Siage
  class ExtensionRostersController < ApplicationController
    skip_forgery_protection
    skip_before_action :load_login_pending_toasts
    skip_before_action :tick_local_automations
    skip_before_action :tick_due_reminders

    def create
      professor = extension_professor
      unless professor
        return render json: { ok: false, error: "unauthorized" }, status: :unauthorized
      end

      payload = roster_payload
      classrooms = Array(payload["classrooms"])
      preview = RosterPreview.new(professor: professor, payload: payload).as_json
      status = preview["empty"] ? "empty" : "pending_review"

      professor.siage_roster_imports.create!(
        status: status,
        payload: payload,
        preview: preview,
        error_message: preview["empty"] ? "A extensão não leu nenhuma turma." : nil
      )

      render json: {
        ok: true,
        status: status,
        classroom_count: preview["classroom_count"],
        student_count: preview["student_count"],
        review_url: "#{request.base_url}#{siage_roster_path}"
      }
    end

    private

    def extension_professor
      token = request.headers["X-Maestro-Token"].presence || params[:token]
      ExtensionToken.professor_for(token) || (professor_signed_in? ? current_professor : nil)
    end

    def roster_payload
      list = params[:classrooms] || params.dig(:siage, :classrooms)
      {
        "classrooms" => Array(list).map { |row| row.respond_to?(:to_unsafe_h) ? row.to_unsafe_h : row.to_h.stringify_keys }
      }
    end
  end
end
