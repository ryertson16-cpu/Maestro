class ActivitiesController < ApplicationController
  before_action :authenticate_professor!
  before_action :set_activity, except: :create

  def sheet
    pdf = Documents::ActivitySheet.new(
      professor: current_professor,
      activity: @activity
    ).render

    send_data pdf,
              filename: sheet_filename,
              type: "application/pdf",
              disposition: "attachment"
  end

  def adapt
    @parent = @activity.adapted? ? @activity.parent_activity : @activity
    @adapted = if @activity.adapted?
                 @activity
               else
                 build_adapted_from(@parent)
               end
    @classroom = current_professor.classrooms.find(@adapted.lesson.classroom_id)
    @students = @classroom.students.order(:name)
  end

  def create
    parent = find_parent_activity
    @classroom = current_professor.classrooms.find(parent.lesson.classroom_id)
    @adapted = build_adapted_from(parent)
    assign_adapted_attributes(@adapted)

    if @adapted.save
      redirect_to grade_levels_path(
        classroom_id: @classroom.id,
        activity_id: @adapted.id,
        kind: "adapted"
      ), notice: "Atividade adaptada criada com sucesso."
    else
      @parent = parent
      @students = @classroom.students.order(:name)
      render :adapt, status: :unprocessable_entity
    end
  end

  def update
    if @activity.adapted? && params[:activity]&.key?(:student_ids)
      assign_adapted_attributes(@activity)
      saved = @activity.save
    else
      saved = @activity.update(regular_activity_params)
    end

    if saved
      redirect_to grade_levels_path(
        classroom_id: @classroom.id,
        activity_id: @activity.id,
        bimester: params[:bimester_filter].presence,
        kind: @activity.adapted? ? "adapted" : params[:kind]
      ), notice: "Atividade atualizada com sucesso."
    elsif @activity.adapted?
      @parent = @activity.parent_activity
      @adapted = @activity
      @students = @classroom.students.order(:name)
      render :adapt, status: :unprocessable_entity
    else
      redirect_to grade_levels_path(
        classroom_id: @classroom.id,
        activity_id: @activity.id,
        bimester: params[:bimester_filter].presence
      ), alert: @activity.errors.full_messages.to_sentence
    end
  end

  private

  def set_activity
    @activity = Activity
      .joins(:lesson)
      .where(
        lessons: {
          classroom_id: current_professor.classrooms.select(:id)
        }
      )
      .includes(lesson: [:classroom, :course], adapted_versions: :activity_recipients, activity_recipients: :student)
      .find(params[:id])

    @classroom = current_professor.classrooms.find(
      @activity.lesson.classroom_id
    )
  rescue ActiveRecord::RecordNotFound
    redirect_to grade_levels_path,
                alert: "Atividade não encontrada ou sem permissão de acesso."
    throw :abort
  end

  def find_parent_activity
    Activity
      .joins(:lesson)
      .where(
        adapted: false,
        lessons: {
          classroom_id: current_professor.classrooms.select(:id)
        }
      )
      .find(params.dig(:activity, :parent_activity_id) || params[:parent_activity_id])
  end

  def build_adapted_from(parent)
    Activity.new(
      lesson: parent.lesson,
      parent_activity: parent,
      adapted: true,
      title: "#{parent.title} (adaptada)",
      activity_type: parent.activity_type,
      due_date: parent.due_date,
      maximum_score: parent.maximum_score,
      bimester: parent.bimester,
      weight: parent.weight,
      description: parent.description,
      instructions: parent.instructions,
      adaptation_kind: "reduced",
      grade_mode: "replaces"
    )
  end

  def assign_adapted_attributes(record)
    attrs = adapted_activity_params
    student_ids = Array(attrs.delete(:student_ids)).map(&:presence).compact

    record.assign_attributes(attrs)
    record.adapted = true
    record.recipient_student_ids = current_professor
                                   .students
                                   .where(id: student_ids)
                                   .pluck(:id)
  end

  def regular_activity_params
    params.require(:activity).permit(:bimester, :weight)
  end

  def adapted_activity_params
    params.require(:activity).permit(
      :title,
      :activity_type,
      :due_date,
      :maximum_score,
      :description,
      :instructions,
      :adaptation_kind,
      :grade_mode,
      :bimester,
      :weight,
      :parent_activity_id,
      student_ids: []
    )
  end

  def sheet_filename
    classroom_slug = @classroom.name.to_s.parameterize(separator: "-").presence || "turma"
    title_slug = @activity.title.to_s.parameterize(separator: "-").presence || "atividade"
    type_slug = @activity.activity_type.to_s.parameterize(separator: "-").presence || "folha"
    prefix = @activity.adapted? ? "adaptada-" : ""

    "#{prefix}#{type_slug}-#{title_slug}-#{classroom_slug}.pdf"
  end
end
