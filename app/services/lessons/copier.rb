module Lessons
  class Copier
    def initialize(professor:, lesson:, classroom:, lesson_date:, copy_activities: true)
      @professor = professor
      @lesson = lesson
      @classroom = classroom
      @lesson_date = lesson_date
      @copy_activities = copy_activities
    end

    def call
      replica = nil
      ActiveRecord::Base.transaction do
        replica = @professor.lessons.create!(
          classroom: @classroom,
          lesson_date: @lesson_date,
          course_id: @lesson.course_id,
          theme: @lesson.theme,
          content: @lesson.content,
          objective: @lesson.objective,
          methodology: @lesson.methodology,
          skills: @lesson.skills,
          siage_period: Siage.period_for_date(@lesson_date).presence || @lesson.siage_period,
          siage_class_mode: @lesson.siage_class_mode,
          siage_class_type: @lesson.siage_class_type,
          siage_time_slot: @lesson.siage_time_slot,
          lesson_plan_template_id: @lesson.lesson_plan_template_id,
          has_activity: @copy_activities && @lesson.has_activity?
        )

        copy_activities!(replica) if @copy_activities
      end
      replica.reload
    end

    private

    def copy_activities!(replica)
      date_delta = @lesson_date - @lesson.lesson_date
      regular = @lesson.activity
      return unless regular

      copied = duplicate_activity(regular, replica, date_delta)
      copy_question_images!(regular, copied)
      return unless same_classroom?

      regular.adapted_versions.each do |adapted|
        copy = duplicate_activity(adapted, replica, date_delta, parent: copied)
        adapted.activity_recipients.each do |recipient|
          copy.activity_recipients.build(student_id: recipient.student_id)
        end
        copy.save!
        copy_question_images!(adapted, copy)
      end
    end

    def copy_question_images!(source, copy)
      from_items = source.activity_questions.order(:position).to_a
      to_items = copy.activity_questions.order(:position).to_a
      from_items.zip(to_items).each do |from, to|
        next if from.blank? || to.blank?

        to.copy_image_from(from)
      end
    end

    def duplicate_activity(source, replica, date_delta, parent: nil)
      copy = replica.activities.build(
        title: source.title,
        activity_type: source.activity_type,
        maximum_score: source.maximum_score,
        due_date: source.due_date + date_delta,
        description: source.description,
        instructions: source.instructions,
        bimester: source.bimester,
        weight: source.weight,
        adapted: source.adapted?,
        adaptation_kind: source.adaptation_kind,
        grade_mode: source.grade_mode,
        parent_activity: parent
      )
      source.activity_questions.each do |item|
        copy.activity_questions.build(
          question_id: item.question_id,
          position: item.position,
          prompt: item.prompt,
          kind: item.kind,
          choices: item.choices,
          correct_letter: item.correct_letter,
          points: item.points,
          bncc_skill: item.bncc_skill
        )
      end
      copy.save! unless copy.adapted?
      copy
    end

    def same_classroom?
      @classroom.id == @lesson.classroom_id
    end
  end
end
