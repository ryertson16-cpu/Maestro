module Enem
  class ActivityBuilder
    def initialize(simulado)
      @simulado = simulado
    end

    def ensure_activity!(classroom = @simulado.classroom)
      activity = existing_activity(classroom)
      if activity
        link_home_activity(activity, classroom)
        return sync_questions!(activity)
      end

      lesson = @simulado.professor.lessons.create!(
        classroom: classroom,
        course: classroom.course,
        lesson_date: @simulado.applied_on,
        theme: @simulado.title,
        has_activity: true,
        siage_time_slot: "1º tempo",
        siage_class_mode: "Avaliação",
        siage_class_type: "Avulso",
        siage_period: Siage.period_for_date(@simulado.applied_on)
      )
      activity = lesson.create_activity!(
        title: @simulado.title,
        activity_type: "Simulado ENEM",
        due_date: @simulado.applied_on,
        maximum_score: 10,
        bimester: @simulado.bimester,
        weight: 1,
        instructions: "Simulado ENEM — 90 itens de Ciências da Natureza e Matemática. A nota usa faixas de acertos do caderno, não o TRI oficial do INEP."
      )
      link_home_activity(activity, classroom)
      sync_questions!(activity)
    end

    def sync_questions!(activity)
      key = @simulado.normalized_key
      existing = activity.activity_questions.order(:position).to_a

      Enem::ScoreScale::QUESTION_COUNT.times do |index|
        item = existing[index] || activity.activity_questions.build
        item.position = index + 1
        item.prompt = prompt_for(index)
        item.kind = "objective"
        item.points = 1
        item.choices = Question::LETTERS.map { |letter| { "letter" => letter, "text" => letter } }
        item.correct_letter = key[index]
        item.save!
      end

      activity
    end

    private

    def existing_activity(classroom)
      return @simulado.activity if home_classroom?(classroom) && @simulado.activity.present?

      Activity
        .regular
        .joins(:lesson)
        .where(
          title: @simulado.title,
          lessons: {
            professor_id: @simulado.professor_id,
            classroom_id: classroom.id,
            lesson_date: @simulado.applied_on
          }
        )
        .order("activities.id desc")
        .first
    end

    def link_home_activity(activity, classroom)
      return unless home_classroom?(classroom)
      return if @simulado.activity_id == activity.id

      @simulado.update!(activity: activity)
    end

    def home_classroom?(classroom)
      classroom&.id == @simulado.classroom_id
    end

    def prompt_for(index)
      area = Enem::ScoreScale::CN_RANGE.cover?(index) ? "Ciências da Natureza" : "Matemática"
      "Questão #{index + 1} — #{area}"
    end
  end
end
