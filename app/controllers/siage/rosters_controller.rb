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

      redirect_to siage_roster_compare_path,
                  notice: "Trouxe do SIAGE: #{result.classrooms} turma(s) nova(s), #{result.students} aluno(s) novo(s) e #{result.enrollments} matrícula(s). Confira quem está na turma errada."
    end

    def compare
      record = current_professor.siage_roster_imports.newest.where.not(status: "failed").first
      unless record
        redirect_to siage_roster_path, alert: "Leia as turmas no SIAGE antes de conferir."
        return
      end

      @import = record
      @diff = RosterDiff.new(professor: current_professor, payload: record.payload)
    end

    def move
      enrollment = current_professor.enrollments.where(status: "active").find(params[:id])
      target = current_professor.classrooms.find(params[:classroom_id])

      if target.id == enrollment.classroom_id
        redirect_to siage_roster_compare_path, alert: "O aluno já está nesta turma."
        return
      end

      student = enrollment.student
      Enrollment.transaction do
        enrollment.update!(status: "finished") unless enrollment.classroom_id == target.id
        existing = current_professor.enrollments.find_by(student: student, classroom: target)
        if existing
          existing.update!(status: "active", enrolled_on: existing.enrolled_on || Date.current)
        else
          current_professor.enrollments.create!(
            student: student,
            classroom: target,
            enrolled_on: Date.current,
            status: "active"
          )
        end
      end

      redirect_to siage_roster_compare_path,
                  notice: "#{student.name} foi para #{target.name}, como no SIAGE."
    rescue ActiveRecord::RecordNotFound
      redirect_to siage_roster_compare_path, alert: "Matrícula ou turma não encontrada."
    rescue ActiveRecord::RecordInvalid => error
      redirect_to siage_roster_compare_path, alert: error.record.errors.full_messages.to_sentence
    end

    def detach
      enrollment = current_professor.enrollments.where(status: "active").find(params[:id])
      name = enrollment.student.name
      room = enrollment.classroom.name
      enrollment.update!(status: "finished")
      redirect_to siage_roster_compare_path,
                  notice: "#{name} saiu da #{room}. O cadastro do aluno permanece."
    rescue ActiveRecord::RecordNotFound
      redirect_to siage_roster_compare_path, alert: "Matrícula não encontrada."
    rescue ActiveRecord::RecordInvalid => error
      redirect_to siage_roster_compare_path, alert: error.record.errors.full_messages.to_sentence
    end
  end
end
