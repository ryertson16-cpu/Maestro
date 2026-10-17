class GradeLevelsController < ApplicationController
  before_action :authenticate_professor!
  before_action :set_grade_level,
                only: %i[edit update destroy]

  def index
    @classrooms = current_professor
                  .classrooms
                  .includes(:grade_level)
                  .order(:name)

    load_classroom_card_stats
    @classroom = find_classroom
    @bimester_filter = selected_bimester_filter
    @activity_kind = params[:kind].to_s == "adapted" ? "adapted" : "regular"
    @all_classroom_activities = activities_for_classroom
    @activities = filtered_activities
    @activity = find_activity
    @exam_activity = exam_activity_for_classroom(@classroom) if @classroom.present?

    prepare_activity_center
  end

  def new
    @grade_level = current_professor
                   .grade_levels
                   .new(active: true)
  end

  def create
    @grade_level = current_professor
                   .grade_levels
                   .new(grade_level_params)

    if @grade_level.save
      redirect_to grade_levels_path,
                  notice: "Nível de ensino criado com sucesso."
    else
      render :new,
             status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @grade_level.update(grade_level_params)
      redirect_to grade_levels_path,
                  notice: "Nível de ensino atualizado com sucesso."
    else
      render :edit,
             status: :unprocessable_entity
    end
  end

  def destroy
    if @grade_level.destroy
      redirect_to grade_levels_path,
                  notice: "Nível de ensino removido com sucesso."
    else
      redirect_to grade_levels_path,
                  alert: @grade_level.errors.full_messages.to_sentence
    end
  end

  def exam_result
    classroom =
      current_professor.classrooms.find(params[:classroom_id])

    activity = exam_activity_for_classroom(classroom)

    unless activity
      redirect_to grade_levels_path(classroom_id: classroom.id),
                  alert: 'Nenhuma atividade com título iniciado por "Prova" foi encontrada para esta turma.'
      return
    end

    students = classroom.students.order(:name)

    submissions = ActivitySubmission
                  .where(
                    activity: activity,
                    student_id: students.select(:id)
                  )
                  .index_by(&:student_id)

    pdf = build_exam_result_pdf(
      classroom: classroom,
      activity: activity,
      students: students,
      submissions: submissions
    )

    send_data pdf.render,
              filename: "resultado-prova-#{normalized_filename(classroom.name)}.pdf",
              type: "application/pdf",
              disposition: "attachment"
  rescue ActiveRecord::RecordNotFound
    redirect_to grade_levels_path,
                alert: "Turma não encontrada."
  end

    def save_submissions
      classroom = current_professor.classrooms.find(params[:classroom_id])
      activity = find_activity_for_classroom(classroom)

      submissions_params.each do |student_id, attributes|
        student = classroom.students.find_by(id: student_id)
        next if student.blank?
        next unless activity.assigned_to?(student)

        submission = ActivitySubmission.find_or_initialize_by(
          activity: activity,
          student: student
        )

        submission.professor = current_professor
        submission.submitted_on = attributes[:submitted_on].presence
        submission.score = NumericScore.parse(attributes[:score])
        submission.save!

        next unless activity.recovery_eligible?
        next if attributes[:recovery_score].blank?

        recovery_grade = RecoveryGrade.find_or_initialize_by(
          student: student,
          classroom: classroom,
          bimester: activity.bimester
        )

        recovery_grade.professor = current_professor
        recovery_grade.score = attributes[:recovery_score]
        recovery_grade.save!
      end

      redirect_to grade_levels_path(
        classroom_id: classroom.id,
        activity_id: activity.id,
        bimester: params[:bimester],
        kind: activity.adapted? ? "adapted" : params[:kind]
      ), flash: {
        maestro_recap: Maestro::ActionRecap.new(current_professor).grades(activity, classroom: classroom)
      }
    rescue ActiveRecord::RecordNotFound
      redirect_to grade_levels_path,
                  alert: "Turma ou atividade não encontrada."
    rescue ActiveRecord::RecordInvalid => error
      redirect_to grade_levels_path(
        classroom_id: classroom&.id,
        activity_id: activity&.id,
        bimester: params[:bimester]
      ), alert: error.record.errors.full_messages.to_sentence
    end

  private

  def exam_activity_for_classroom(classroom)
    activities =
      current_professor
        .lessons
        .where(classroom_id: classroom.id)
        .joins(:activity)
        .includes(activity: { adapted_versions: :activity_submissions })
        .order(lesson_date: :desc)
        .filter_map { |lesson| lesson.activity }

    activities.find do |activity|
      activity.title.to_s
              .strip
              .downcase
              .start_with?("prova")
    end
  end

  def build_exam_result_pdf(classroom:, activity:, students:, submissions:)
    letterhead = Documents::Letterhead.new(current_professor)

    pdf = Prawn::Document.new(
      page_size: "A4",
      page_layout: :portrait,
      margin: 36,
      info: {
        Title: "Resultado da prova - #{classroom.name}",
        Author: current_professor.respond_to?(:name) ?
          current_professor.name :
          "Sistema escolar"
      }
    ) do |document|
      letterhead.draw(
        document,
        title: "RESULTADO DA PROVA",
        subtitle: "#{classroom.name} · #{activity.title}"
      )

      if activity.lesson&.lesson_date.present?
        document.fill_color "333333"
        document.text(
          "Data da prova: #{format_date(activity.lesson.lesson_date)}",
          size: 10,
          align: :center
        )
        document.move_down 16
      end

      document.fill_color "000000"

      rows = [
        ["Aluno", "Nota", "Resultado"]
      ]

      students.each do |student|
        source = activity.replacing_version_for(student) || activity
        submission =
          if source == activity
            submissions[student.id]
          else
            source.activity_submissions.find { |item| item.student_id == student.id }
          end
        score = submission&.score

        result =
          if !NumericScore.recorded?(score)
            "Sem nota"
          elsif score.to_f >= 6
            "Aprovado"
          else
            "Em recuperação"
          end

        formatted_score =
          if NumericScore.recorded?(score)
            format_score(score)
          else
            "—"
          end

        rows << [
          student.name.to_s,
          formatted_score,
          result
        ]
      end

      if students.any?
        document.table(
          rows,
          width: document.bounds.width,
          column_widths: [
            document.bounds.width * 0.55,
            document.bounds.width * 0.20,
            document.bounds.width * 0.25
          ],
          header: true,
          row_colors: ["FFFFFF", "F4F7FA"],
          cell_style: {
            padding: [8, 8],
            size: 10,
            borders: [:bottom],
            border_color: "D9E2F3",
            valign: :center
          }
        ) do |table|
          table.row(0).background_color = "1F4E79"
          table.row(0).text_color = "FFFFFF"
          table.row(0).font_style = :bold

          table.column(1).align = :center
          table.column(2).align = :center
        end
      else
        document.text "Nenhum aluno encontrado na turma."
      end

      document.move_down 20

      document.fill_color "666666"
      document.text(
        "Critério: nota maior ou igual a 6,0 — Aprovado. " \
        "Nota inferior a 6,0 — Em recuperação.",
        size: 9
      )

      document.number_pages(
        "Página <page> de <total>",
        at: [document.bounds.right - 100, 0],
        align: :right,
        size: 8,
        color: "777777"
      )
    end

    pdf
  ensure
    letterhead&.cleanup
  end

  def format_date(value)
    return "Não informada" if value.blank?

    I18n.l(
      value.to_date,
      format: "%d/%m/%Y"
    )
  end

  def format_score(value)
    format("%.1f", value.to_f).tr(".", ",")
  end

  def normalized_filename(value)
    value.to_s
        .parameterize(separator: "-")
        .presence || "turma"
  end

  def set_grade_level
    @grade_level = current_professor
                   .grade_levels
                   .find(params[:id])
  end

  def grade_level_params
    params.require(:grade_level).permit(
      :name,
      :description,
      :active
    )
  end

  def find_classroom
    resolve_classroom(fallback: true)
  rescue ActiveRecord::RecordNotFound
    remembered_classroom
  end

  def activities_for_classroom
    return Activity.none if @classroom.blank?

    Activity
      .joins(:lesson)
      .where(
        lessons: {
          classroom_id: @classroom.id,
          professor_id: current_professor.id
        }
      )
      .includes(
        :lesson,
        :parent_activity,
        :activity_submissions,
        :activity_recipients,
        adapted_versions: :activity_recipients
      )
      .order("activities.due_date DESC", "activities.created_at DESC")
  end

  def find_activity
    return nil if @activities.blank?

    activity_id = params[:activity_id].presence

    if activity_id.present?
      @activities.find { |activity| activity.id == activity_id.to_i } || @activities.first
    else
      @activities.first
    end
  end

  def selected_bimester_filter
    number = params[:bimester].to_i
    (1..4).cover?(number) ? number : nil
  end

  def filtered_activities
    scoped =
      if @activity_kind == "adapted"
        @all_classroom_activities.select(&:adapted?)
      else
        @all_classroom_activities.reject(&:adapted?)
      end

    return scoped if @bimester_filter.blank?

    scoped.select { |activity| activity.bimester == @bimester_filter }
  end

  def load_classroom_card_stats
    classroom_ids = @classrooms.map(&:id)

    @classroom_student_counts = Enrollment
                                .where(professor: current_professor, classroom_id: classroom_ids)
                                .group(:classroom_id)
                                .count

    student_ids_by_classroom =
      Enrollment
        .where(professor: current_professor, classroom_id: classroom_ids)
        .pluck(:classroom_id, :student_id)
        .each_with_object(Hash.new { |hash, key| hash[key] = [] }) do |(classroom_id, student_id), hash|
          hash[classroom_id] << student_id
        end

    activities =
      Activity
        .joins(:lesson)
        .where(lessons: { professor_id: current_professor.id, classroom_id: classroom_ids })
        .includes(:activity_submissions, :lesson, :activity_recipients, adapted_versions: :activity_recipients)

    @classroom_pending_counts = Hash.new(0)
    @activity_pending_counts = Hash.new(0)

    activities.each do |activity|
      classroom_id = activity.lesson.classroom_id
      student_ids = student_ids_by_classroom[classroom_id] || []
      students = student_ids.map { |id| Student.new(id: id) }
      delivered_ids = activity.activity_submissions.filter_map do |submission|
        submission.student_id if submission.submitted_on.present?
      end
      pending = students.count do |student|
        activity.required_delivery_for?(student) && delivered_ids.exclude?(student.id)
      end
      @activity_pending_counts[activity.id] = pending
      @classroom_pending_counts[classroom_id] += pending
    end
  end

  def find_activity_for_classroom(classroom)
    activity = Activity
               .joins(:lesson)
               .where(
                 lessons: {
                   classroom_id: classroom.id,
                   professor_id: current_professor.id
                 }
               )
               .includes(:adapted_versions, :activity_recipients)
               .find_by(id: params[:activity_id])

    raise ActiveRecord::RecordNotFound if activity.blank?

    activity
  end

  def prepare_activity_center
    @submissions_by_student = {}
    @recovery_grades_by_student = {}
    @tracking_rows = []
    @tracking_summary = {
      in_progress: 0,
      delivered: 0,
      delivered_late: 0,
      not_delivered: 0
    }

    return if @activity.blank? || @classroom.blank?

    students = @classroom.students.order(:name).to_a
    enrollments_by_student = Enrollment.where(classroom: @classroom).index_by(&:student_id)
    @replaced_students = []

    if @activity.adapted?
      students = students.select { |student| @activity.assigned_to?(student) }
    else
      @replaced_students = students.select { |student| @activity.replacing_version_for(student).present? }
      students -= @replaced_students
    end

    submissions = ActivitySubmission.where(
      activity: @activity,
      student_id: students.map(&:id)
    )

    @submissions_by_student = submissions.index_by(&:student_id)

    if @activity.recovery_eligible?
      recovery_grades = @classroom.recovery_grades.where(
        bimester: @activity.bimester,
        student_id: students.map(&:id)
      )

      @recovery_grades_by_student = recovery_grades.index_by(&:student_id)
    end

    status_rank = {
      not_delivered: 0,
      in_progress: 1,
      delivered_late: 2,
      delivered: 3
    }

    @tracking_rows = students.map do |student|
      submission = @submissions_by_student[student.id]
      status =
        if submission.present?
          submission.status
        elsif Date.current > @activity.due_date
          :not_delivered
        else
          :in_progress
        end

      @tracking_summary[status] += 1

      {
        student: student,
        enrollment: enrollments_by_student[student.id],
        submission: submission,
        recovery_grade: @recovery_grades_by_student[student.id],
        status: status
      }
    end.sort_by do |row|
      [status_rank.fetch(row[:status], 9), row[:student].name.to_s]
    end
  end

  def submissions_params
    params
      .fetch(:submissions, {})
      .permit!
  end
end
