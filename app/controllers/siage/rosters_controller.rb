module Siage
  class RostersController < ApplicationController
    before_action :authenticate_professor!

    def show
      @import = current_professor.siage_roster_imports.newest.first
      if params[:nova].present? && @import&.pending_review?
        @import.update!(status: "failed", error_message: "Substituída por nova leitura.")
        @import = nil
      end
      if @import&.pending_review?
        @preview = @import.preview.presence || RosterPreview.new(professor: current_professor, payload: @import.payload).as_json
        render :review
        return
      end

      @handoff = Handoff.payload(
        professor: current_professor,
        origin: request.base_url,
        mode: "roster"
      )
      @resumo = {
        cpf: current_professor.cpf.present?,
        senha: current_professor.siage_password.present?
      }
    end

    def status
      record = current_professor.siage_roster_imports.newest.first
      render json: {
        ok: true,
        status: record&.status,
        ready: record&.pending_review? == true
      }
    end

    def apply
      record = current_professor.siage_roster_imports.newest.first
      unless record&.pending_review?
        redirect_to siage_roster_path, alert: "Não há lista do SIAGE para gravar."
        return
      end

      preview = record.preview.presence || RosterPreview.new(professor: current_professor, payload: record.payload).as_json
      if preview["empty"]
        record.update!(status: "empty", error_message: "A extensão não leu nenhuma turma.")
        redirect_to siage_roster_path, alert: "A extensão não leu nenhuma turma. Tente de novo."
        return
      end

      result = RosterImporter.new(professor: current_professor, preview: preview).call
      record.update!(status: "applied", applied_at: Time.current, preview: preview)

      redirect_to classrooms_path,
                  notice: "Trouxe do SIAGE: #{result.classrooms} turma(s) nova(s), #{result.students} aluno(s) novo(s) e #{result.enrollments} matrícula(s). Nada que já existia no caderno foi apagado."
    end
  end
end
