class ClassroomsController < ApplicationController
  before_action :authenticate_professor!
  before_action :set_classroom, only: %i[show edit update destroy report]

  def index
    @classrooms = current_professor
                  .classrooms
                  .includes(:school_course, :grade_level)
                  .order(active: :desc, school_year: :desc, name: :asc)

    @classroom_student_counts = Enrollment
                                .where(professor: current_professor, status: "active")
                                .group(:classroom_id)
                                .count
  end

  def report
    enrollments = @classroom.enrollments
                            .where(status: "active")
                            .includes(:student)
                            .joins(:student)
                            .order("students.name")

    pdf = Documents::ClassroomRoster.new(
      professor: current_professor,
      classroom: @classroom,
      enrollments: enrollments
    ).render

    send_data pdf,
              filename: "relacao-alunos-#{@classroom.name.to_s.parameterize}.pdf",
              type: "application/pdf",
              disposition: "attachment"
  end

  def show
    @available_classrooms = current_professor
                            .classrooms
                            .where.not(id: @classroom.id)
                            .order(:name)

    @search = params[:search].to_s.strip
    @frequency_filter = params[:frequency].to_s

    all_enrollments = @classroom.enrollments
                                .where(status: "active")
                                .includes(:student, :attendance_records)
                                .joins(:student)
                                .order("students.name")

    @attendance_month = Date.current.beginning_of_month
    month_records = AttendanceRecord
                    .where(
                      professor: current_professor,
                      enrollment_id: all_enrollments.map(&:id),
                      attendance_date: Attendance::Frequency.month_range(@attendance_month)
                    )
                    .group_by(&:enrollment_id)

    @attendance_stats = {}

    all_enrollments.each do |enrollment|
      records = month_records[enrollment.id] || []
      stats = Attendance::Frequency.snapshot(records)
      @attendance_stats[enrollment.id] = stats
    end

    @enrollments = all_enrollments.select do |enrollment|
      student = enrollment.student
      stats = @attendance_stats[enrollment.id]

      matches_search =
        @search.blank? ||
        student.name.to_s.downcase.include?(@search.downcase) ||
        student.registration_number.to_s.downcase.include?(@search.downcase)

      matches_frequency =
        case @frequency_filter
        when "regular"
          stats[:situation] == "regular"
        when "attention"
          stats[:situation] == "attention"
        when "low"
          stats[:situation] == "low"
        when "without_records"
          stats[:situation] == "without_records"
        else
          true
        end

      matches_search && matches_frequency
    end

    percentages = @attendance_stats.values.filter_map do |stats|
      stats[:percentage]
    end

    @students_count = all_enrollments.size
    @students_without_records = @attendance_stats.values.count do |stats|
      stats[:percentage].nil?
    end

    @students_low_frequency = @attendance_stats.values.count do |stats|
      Attendance::Frequency.below_minimum?(stats[:percentage])
    end

    @average_frequency =
      if percentages.empty?
        nil
      else
        (percentages.sum.to_f / percentages.size).round(1)
      end

    @total_lessons =
      AttendanceRecord
        .where(
          professor: current_professor,
          enrollment_id: all_enrollments.map(&:id),
          attendance_date: Attendance::Frequency.month_range(@attendance_month)
        )
        .select(:attendance_date)
        .distinct
        .count

    @classroom_activities =
      Activity
        .joins(:lesson)
        .where(
          lessons: {
            classroom_id: @classroom.id,
            professor_id: current_professor.id
          }
        )
        .includes(:lesson, :activity_submissions)
        .order(:due_date, :title)

    @activities_count = @classroom_activities.size

    @pending_activity_rows = []

    all_enrollments.each do |enrollment|
      student = enrollment.student

      @classroom_activities.each do |activity|
        submission =
          activity.activity_submissions.find do |item|
            item.student_id == student.id
          end

        next if submission&.submitted_on.present?

        days_late =
          if activity.due_date.present?
            [Date.current - activity.due_date, 0].max.to_i
          else
            0
          end

        @pending_activity_rows << {
          student: student,
          activity: activity,
          days_late: days_late
        }
      end
    end

    @pending_activity_rows.sort_by! do |row|
      [-row[:days_late].to_i, row[:student].name.to_s]
    end
  end

  def new
    @classroom = current_professor.classrooms.new(
      school_year: Date.current.year,
      active: true
    )

    load_form_options
  end

  def create
    @classroom = current_professor.classrooms.new(classroom_params)
    assign_owned_relations

    if @classroom.save
      remember_current_classroom(@classroom)
      redirect_to classroom_path(@classroom), notice: "Turma criada com sucesso."
    else
      load_form_options
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    load_form_options
  end

  def update
    if @classroom.update(classroom_params)
      redirect_to classroom_path(@classroom),
                  notice: "Turma atualizada com sucesso."
    else
      load_form_options
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @classroom.destroy
      redirect_to classrooms_path, notice: "Turma removida com sucesso."
    else
      redirect_to classrooms_path,
                  alert: @classroom.errors.full_messages.to_sentence
    end
  end

  private

  def set_classroom
    @classroom = current_professor.classrooms.find(params[:id])
  end

  def classroom_params
    params.require(:classroom).permit(
      :name,
      :school_course_id,
      :course_id,
      :grade_level_id,
      :school_year,
      :shift,
      :active
    )
  end

  def assign_owned_relations
    @classroom.course =
      current_professor.courses.find_by(id: classroom_params[:course_id])

    @classroom.grade_level =
      current_professor.grade_levels.find_by(
        id: classroom_params[:grade_level_id]
      )
  end

  def load_form_options
    @school_courses = current_professor
                      .school_courses
                      .active
                      .order(:name)

    @grade_levels = current_professor
                    .grade_levels
                    .where(active: true)
                    .order(:name)

    @courses = current_professor
               .courses
               .active
               .order(:knowledge_area, :name)
  end
end
