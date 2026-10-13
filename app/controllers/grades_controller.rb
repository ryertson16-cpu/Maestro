class GradesController < ApplicationController
  before_action :authenticate_professor!
  before_action :set_classroom

  def index
    @bimester = selected_bimester
    @settings = load_bimester_settings
    @setting = @settings[@bimester]

    @students = @classroom.students.order(:name)
    @activities = load_activities
    @recovery_grades_by_student = load_recovery_grades
    @rows = build_student_rows
    @statistics = build_statistics
  end

  def save_bimester_settings
    setting = @classroom.bimester_settings.find_or_initialize_by(
      bimester: params[:bimester].to_i
    )

    setting.minimum_score = params[:minimum_score]

    if setting.save
      redirect_to grades_path(
        classroom_id: @classroom.id,
        bimester: setting.bimester
      ), notice: "Configuração do bimestre salva com sucesso."
    else
      redirect_to grades_path(
        classroom_id: @classroom.id,
        bimester: setting.bimester
      ), alert: setting.errors.full_messages.to_sentence
    end
  end

  def close_bimester
    setting = @classroom.bimester_settings.find_or_initialize_by(
      bimester: params[:bimester].to_i
    )

    setting.minimum_score =
      params[:minimum_score].presence || 6.0

    setting.save!

    if setting.closed?
      setting.reopen!
      message = "Bimestre reaberto para edição."
    else
      setting.close!
      message = "Bimestre fechado com sucesso."
    end

    redirect_to grades_path(
      classroom_id: @classroom.id,
      bimester: setting.bimester
    ), notice: message
  rescue ActiveRecord::RecordInvalid => error
    redirect_to grades_path(
      classroom_id: @classroom.id,
      bimester: params[:bimester]
    ), alert: error.record.errors.full_messages.to_sentence
  end

  def save_recovery
    student = @classroom.students.find(params[:student_id])
    bimester = params[:bimester].to_i

    recovery = RecoveryGrade.find_or_initialize_by(
      student: student,
      classroom: @classroom,
      bimester: bimester
    )

    recovery.professor = current_professor
    recovery.score = params[:score]
    recovery.notes = params[:notes]

    recovery.save!

    redirect_to grades_path(
      classroom_id: @classroom.id,
      bimester: bimester
    ), flash: {
      maestro_recap: Maestro::ActionRecap.new(current_professor).recovery(
        classroom: @classroom,
        bimester: bimester,
        student_name: student.name.to_s.split.first
      )
    }
  rescue ActiveRecord::RecordNotFound
    redirect_to grades_path(
      classroom_id: @classroom.id,
      bimester: params[:bimester]
    ), alert: "Aluno não encontrado."
  rescue ActiveRecord::RecordInvalid => error
    redirect_to grades_path(
      classroom_id: @classroom.id,
      bimester: params[:bimester]
    ), alert: error.record.errors.full_messages.to_sentence
  end

  def report
    @bimester = selected_bimester

    @setting = @classroom.bimester_settings.find_by(
      bimester: @bimester
    )

    @students = @classroom.students.order(:name)
    @activities = load_activities
    @recovery_grades_by_student = load_recovery_grades
    @rows = build_student_rows

    pdf = build_grades_pdf

    send_data pdf.render,
              filename: "boletim-#{@classroom.name.parameterize}-bimestre-#{@bimester}.pdf",
              type: "application/pdf",
              disposition: "attachment"
  end

  private

  def set_classroom
    @classroom = resolve_classroom(fallback: true)

    if @classroom.blank?
      redirect_to classrooms_path, alert: "Cadastre uma turma para lançar as médias."
      return
    end
  rescue ActiveRecord::RecordNotFound
    redirect_to classrooms_path, alert: "Turma não encontrada."
  end

  def selected_bimester
    value = params[:bimester].to_i

    (1..4).cover?(value) ? value : 1
  end

  def load_bimester_settings
    @classroom.bimester_settings.index_by(&:bimester).tap do |settings|
      (1..4).each do |number|
        settings[number] ||= @classroom.bimester_settings.build(
          bimester: number,
          minimum_score: 6.0
        )
      end
    end
  end

  def load_activities
    Activity
      .joins(:lesson)
      .where(
        lessons: {
          classroom_id: @classroom.id
        },
        bimester: @bimester
      )
      .includes(:activity_submissions, :lesson, :activity_recipients, adapted_versions: %i[activity_recipients activity_submissions])
      .order(due_date: :asc)
  end

  def build_student_rows
    @students.map do |student|
      recovery = @recovery_grades_by_student[student.id]

      grades = @activities.filter_map do |activity|
        next unless activity.assigned_to?(student)
        next if activity.regular? && activity.replacing_version_for(student).present?

        submission = activity.activity_submissions.find do |item|
          item.student_id == student.id
        end

        original_score = submission&.score
        recovery_score = recovery&.score

        recovery_applied =
          activity.title.to_s.match?(/\bprova\b/i) &&
          NumericScore.recorded?(original_score) &&
          NumericScore.recorded?(recovery_score) &&
          recovery_score.to_d > original_score.to_d

        effective_score =
          if recovery_applied
            recovery_score
          else
            original_score
          end

        {
          activity: activity,
          submission: submission,
          score: effective_score,
          original_score: original_score,
          recovery_applied: recovery_applied
        }
      end

      valid_grades = grades.select do |grade|
        NumericScore.recorded?(grade[:score]) &&
          grade[:activity].counts_toward_average_for?(student)
      end

      weighted_total = valid_grades.sum do |grade|
        grade[:score].to_d * grade[:activity].weight.to_d
      end

      total_weight = valid_grades.sum do |grade|
        grade[:activity].weight.to_d
      end

      average =
        if total_weight.zero?
          nil
        else
          (weighted_total / total_weight).round(2)
        end

      final_score = NumericScore.round_final([average, recovery&.score&.to_d].compact.max)

      {
        student: student,
        grades: grades,
        average: average,
        recovery: recovery,
        final_score: final_score,
        situation: situation_for(
          final_score,
          @setting&.minimum_score || 6.0
        )
      }
    end
  end

  def situation_for(score, minimum_score)
    return :without_grades unless NumericScore.recorded?(score)
    return :approved if score >= minimum_score.to_d

    :recovery
  end

  def build_statistics
    scores = @rows.filter_map do |row|
      row[:final_score]
    end

    {
      students: @students.count,
      activities: @activities.count,
      average: scores.any? ? (scores.sum / scores.size).round(2) : nil,
      approved: @rows.count do |row|
        row[:situation] == :approved
      end,
      recovery: @rows.count do |row|
        row[:situation] == :recovery
      end,
      without_grades: @rows.count do |row|
        row[:situation] == :without_grades
      end
    }
  end

  def build_grades_pdf
    letterhead = Documents::Letterhead.new(current_professor)

    pdf = Prawn::Document.new(
      page_size: "A4",
      page_layout: :landscape,
      margin: 28
    ) do |document|
      letterhead.draw(
        document,
        title: "BOLETIM BIMESTRAL",
        subtitle: "#{@classroom.name} — #{@bimester}º Bimestre"
      )

      rows = [
        [
          "Aluno",
          "Média",
          "Recuperação",
          "Nota final",
          "Situação"
        ]
      ]

      @rows.each do |row|
        rows << [
          row[:student].name,
          format_score(row[:average]),
          format_score(row[:recovery]&.score),
          format_score(row[:final_score]),
          situation_label(row[:situation])
        ]
      end

      document.table(
        rows,
        width: document.bounds.width,
        header: true,
        row_colors: ["FFFFFF", "F5F7FB"],
        cell_style: {
          padding: 6,
          size: 9,
          borders: [:bottom],
          border_color: "E5E8F0"
        }
      ) do |table|
        table.row(0).background_color = "5B4BDB"
        table.row(0).text_color = "FFFFFF"
        table.row(0).font_style = :bold
      end
    end

    pdf
  ensure
    letterhead&.cleanup
  end

  def format_score(score)
    NumericScore.recorded?(score) ? format("%.1f", NumericScore.round_final(score)) : "—"
  end

  def situation_label(situation)
    {
      approved: "Aprovado",
      recovery: "Recuperação",
      without_grades: "Sem notas"
    }.fetch(situation)
  end

  def load_recovery_grades
    RecoveryGrade
      .where(
        classroom: @classroom,
        bimester: @bimester,
        student_id: @students.select(:id)
      )
      .index_by(&:student_id)
  end
end