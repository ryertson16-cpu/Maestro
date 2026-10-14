module Siage
  class ExtensionResultsController < ApplicationController
    skip_forgery_protection
    skip_before_action :load_login_pending_toasts
    skip_before_action :tick_local_automations
    skip_before_action :tick_due_reminders

    def create
      professor = extension_professor
      unless professor
        return render json: { ok: false, error: "unauthorized" }, status: :unauthorized
      end

      if params[:kind].to_s == "grades"
        return create_grades(professor)
      end

      create_lessons(professor)
    end

    private

    def create_lessons(professor)
      status = params[:status].to_s
      unless status.in?(%w[verified failed already_registered])
        return render json: { ok: false, error: "invalid_status" }, status: :unprocessable_entity
      end

      updated = Siage::LedgerStatus.new(professor).apply(
        lesson_ids: params[:lesson_ids],
        status: status,
        message: params[:message]
      )

      render json: { ok: true, updated: updated }
    end

    def create_grades(professor)
      status = params[:status].to_s
      unless status.in?(%w[partial launched failed])
        return render json: { ok: false, error: "invalid_status" }, status: :unprocessable_entity
      end

      classroom = professor.classrooms.find_by(id: params[:classroom_id])
      unless classroom
        return render json: { ok: false, error: "classroom_not_found" }, status: :unprocessable_entity
      end

      shipment = Siage::GradeStatus.new(professor).apply(
        classroom: classroom,
        bimester: params[:bimester],
        status: status,
        message: params[:message]
      )

      render json: { ok: true, updated: shipment.present? ? 1 : 0 }
    end

    def extension_professor
      token = request.headers["X-Maestro-Token"].presence || params[:token]
      Siage::ExtensionToken.professor_for(token) || (professor_signed_in? ? current_professor : nil)
    end
  end
end
