module Activities
  class OnlineFormPreview
    def initialize(professor:, rows:, title: nil, lesson_date: nil)
      @professor = professor
      @rows = rows
      @title = title.to_s.strip.presence
      @lesson_date = lesson_date.presence&.to_date
      @classrooms = professor.classrooms.includes(:students).order(:name).to_a
    end

    def max_raw_score
      scores = @rows.map(&:raw_score).compact
      [scores.max, question_count, 10].compact.max.to_f
    end

    def question_count
      @rows.map { |row| row.answers.size }.max.to_i
    end

    def scaled_score(raw)
      return if raw.blank? || max_raw_score <= 0

      value = (raw.to_f / max_raw_score) * 10
      [[value.round(1), 0].max, 10].min
    end

    def items
      @rows.map { |row| item_for(row) }
    end

    def suggested_date
      times = @rows.map(&:submitted_at).compact
      (times.min || Time.current).to_date
    end

    def suggested_title
      Activities::OnlineFormImporter::CANONICAL_TITLE
    end

    private

    def item_for(row)
      classroom = match_classroom(row.classroom_label)
      students = classroom ? classroom.students.to_a : @professor.students.to_a
      student = match_student(row.name, students)
      existing = existing_score_for(classroom, student)

      {
        name: row.name,
        classroom_label: row.classroom_label,
        classroom_id: classroom&.id,
        student_id: student&.id,
        submitted_at: row.submitted_at,
        raw_score: row.raw_score,
        score: existing || scaled_score(row.raw_score),
        already_scored: NumericScore.recorded?(existing),
        match_label: match_label(classroom, student, students, row.name, existing)
      }
    end

    def match_classroom(label)
      return if label.blank?

      hits = @classrooms.select { |room| Lessons::NameMatcher.classroom_in_text?(label, room.name) }
      return hits.first if hits.one?

      exact = hits.select do |room|
        Lessons::NameMatcher.serie_and_letter(label) == Lessons::NameMatcher.serie_and_letter(room.name)
      end
      exact.one? ? exact.first : nil
    end

    def match_student(name, students)
      Lessons::NameMatcher.match_student(name, students)
    end

    def match_label(classroom, student, students, name, existing)
      if NumericScore.recorded?(existing)
        return "Já tem nota nesta atividade — não será alterada"
      end
      return "Turma não localizada" if classroom.blank?
      return "Correspondência única pelo nome" if student

      scored = students.count { |item| Lessons::NameMatcher.student_name_score(item.name, name) >= 50 }
      first_names = Lessons::NameMatcher.first_name_hits(name, students)
      return "Nome repetido na turma: escolha o aluno" if scored > 1 || first_names.size > 1

      "Aluno não localizado: escolha manualmente"
    end

    def existing_score_for(classroom, student)
      return unless classroom && student && @title.present? && @lesson_date.present?

      activity = existing_activity_for(classroom)
      return unless activity

      activity.activity_submissions.find { |item| item.student_id == student.id }&.score
    end

    def existing_activity_for(classroom)
      @existing_activities ||= {}
      @existing_activities[classroom.id] ||= Activities::OnlineFormImporter.existing_activity(
        professor: @professor,
        classroom: classroom,
        title: @title,
        lesson_date: @lesson_date
      )
    end
  end
end
