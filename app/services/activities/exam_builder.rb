module Activities
  class ExamBuilder
    Result = Struct.new(:added, :from_bank, :generated, :message, keyword_init: true)

    def initialize(professor:, activity:, brain: nil)
      @professor = professor
      @activity = activity
      @brain = brain
      @composer = Activities::Composer.new(activity)
    end

    def build!(topic:, quantity:, course_id: nil, mix: "objective", difficulty: nil)
      wanted = quantity.to_i.clamp(1, 40)
      missing = wanted - @activity.activity_questions.count
      if missing <= 0
        return Result.new(
          added: 0,
          from_bank: 0,
          generated: 0,
          message: "Esta prova já tem #{@activity.activity_questions.count} questões."
        )
      end

      course = @professor.courses.find_by(id: course_id) if course_id.present?
      from_bank = pull_from_bank(topic, missing, course, mix)
      still = wanted - @activity.activity_questions.reload.count
      generated = 0
      generated = generate_with_lira(topic, still, course, difficulty) if still.positive? && lira_ready?

      added = from_bank + generated
      Result.new(
        added: added,
        from_bank: from_bank,
        generated: generated,
        message: summary(added, from_bank, generated, still - generated)
      )
    end

    private

    def pull_from_bank(topic, missing, course, mix)
      scope = @professor.questions.order(updated_at: :desc)
      scope = scope.search(topic) if topic.to_s.strip.present?
      scope = scope.where(course_id: [nil, course.id]) if course
      scope = scope.objective if mix.to_s != "mixed"
      used = @activity.activity_questions.filter_map(&:question_id)
      scope = scope.where.not(id: used) if used.any?

      added = 0
      scope.limit(missing).each do |question|
        @composer.add(question)
        added += 1
      end
      added
    end

    def lira_ready?
      @brain.present? || Lira.llm_enabled?
    end

    def generate_with_lira(topic, count, course, difficulty)
      return 0 unless lira_ready?
      return 0 if topic.to_s.strip.blank?

      payload = ask_lira(topic, count, course, difficulty)
      return 0 if payload.blank?

      added = 0
      Array(payload).first(count).each do |row|
        next unless row.is_a?(Hash)

        question = build_generated_question(row, course, topic)
        next unless question&.persisted?

        @composer.add(question)
        added += 1
      end
      added
    end

    def ask_lira(topic, count, course, difficulty)
      text = brain.extract_text(
        generation_prompt(topic, count, course, difficulty),
        system: "Você escreve questões objetivas escolares em português do Brasil. JSON puro, sem markdown."
      )
      parsed = parse_json(text)
      return if parsed.blank?

      parsed["questions"] || parsed["questoes"] || parsed
    end

    def brain
      @brain || Lira::Brain.new(Lira::Toolkit.new(@professor))
    end

    def generation_prompt(topic, count, course, difficulty)
      discipline = course&.name.presence || @activity.lesson.course&.name.presence || "a disciplina da turma"
      level = difficulty.to_s.strip.presence || "adequado ao ensino médio"

      <<~PROMPT
        Crie #{count} questões objetivas inéditas sobre "#{topic}" para #{discipline}.
        Nível: #{level}.
        Cada item tem enunciado, cinco alternativas A–E e uma letra correta.
        Não copie prova publicada. Linguagem de sala de aula da rede pública.

        Responda só JSON:
        {"questions":[{"prompt":"...","choices":{"A":"...","B":"...","C":"...","D":"...","E":"..."},"correct":"A","bncc_skill":null}]}
      PROMPT
    end

    def parse_json(content)
      return if content.blank?

      JSON.parse(content[/\{.*\}/m].to_s)
    rescue JSON::ParserError
      nil
    end

    def build_generated_question(row, course, topic)
      data = row.stringify_keys
      prompt = data["prompt"].to_s.strip
      return if prompt.blank?

      choices_hash = data["choices"] || data["alternativas"] || {}
      texts = Question::LETTERS.map { |letter| choices_hash[letter].to_s.presence || choices_hash[letter.downcase].to_s }
      choices = Question.normalize_choices(Question::LETTERS, texts)
      correct = data["correct"].to_s.upcase.presence || data["gabarito"].to_s.upcase
      return unless Question::LETTERS.include?(correct)
      return if choices.size < 2

      @professor.questions.create(
        prompt: prompt,
        kind: "objective",
        choices: choices,
        correct_letter: correct,
        points: 1,
        course: course,
        tag: topic.to_s.truncate(80),
        bncc_skill: data["bncc_skill"].presence
      )
    end

    def summary(added, from_bank, generated, leftover)
      return "Não encontrei questões no banco nem consegui gerar com a Lira. Inclua no banco ou revise o assunto." if added.zero?

      parts = ["Incluí #{added} #{added == 1 ? 'questão' : 'questões'}"]
      parts << "#{from_bank} do banco" if from_bank.positive?
      parts << "#{generated} geradas pela Lira" if generated.positive?
      parts << "Faltaram #{leftover}" if leftover.positive?
      "#{parts.first} (#{parts[1..].join('; ')})."
    end
  end
end
