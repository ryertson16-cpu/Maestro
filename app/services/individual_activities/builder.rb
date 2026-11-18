module IndividualActivities
  class Builder
    def initialize(professor:, classroom:, student:, questions:)
      @professor = professor
      @classroom = classroom
      @student = student
      @questions = Array(questions)
    end

    def create!
      raise ArgumentError, "Escolha ao menos uma questão" if @questions.empty?
      raise ArgumentError, "O aluno não está nesta turma" unless active_student?

      Activity.transaction do
        lesson = build_lesson
        lesson.save!
        activity = build_activity(lesson)
        activity.activity_recipients.build(student: @student)
        activity.save!
        copy_questions(activity)
        activity
      end
    end

    private

    def active_student?
      Enrollment.exists?(
        professor: @professor,
        classroom: @classroom,
        student: @student,
        status: "active"
      )
    end

    def build_lesson
      lesson = @professor.lessons.new(
        classroom: @classroom,
        course: @classroom.course,
        lesson_date: Date.current,
        theme: "Atividade de #{@student.name}",
        has_activity: false,
        individual: true,
        siage_time_slot: "1º tempo",
        siage_class_mode: "Avaliação",
        siage_class_type: "Avulso",
        siage_period: Siage.period_for_date(Date.current)
      )
      lesson.skip_attendance_link = true
      lesson
    end

    def build_activity(lesson)
      points = @questions.sum { |question| question.points.to_d }
      lesson.activities.new(
        adapted: true,
        adaptation_kind: "format",
        grade_mode: "complements",
        title: "Atividade de #{@student.name}",
        activity_type: "Atividade individual",
        due_date: Date.current,
        maximum_score: points.positive? ? points : 1,
        weight: 1,
        bimester: Siage.bimester_for_date(Date.current)
      )
    end

    def copy_questions(activity)
      @questions.each_with_index do |question, index|
        item = ActivityQuestion.snapshot_from(question, position: index + 1)
        item.activity = activity
        item.save!
        item.copy_image_from(question)
      end
    end
  end
end
