module Documents
  class ActivitySheet
    BLANK_QUESTION_COUNT = 8

    def initialize(professor:, activity:)
      @professor = professor
      @activity = activity
      @lesson = activity.lesson
      @classroom = @lesson.classroom
      @letterhead = Letterhead.new(professor)
    end

    def render
      pdf = Prawn::Document.new(
        page_size: "A4",
        page_layout: :portrait,
        margin: 36,
        info: {
          Title: "#{@activity.activity_type} - #{@activity.title}",
          Author: @professor.name.presence || "Maestro"
        }
      ) do |document|
        @letterhead.draw(
          document,
          title: @activity.adapted? ? "#{@activity.activity_type} · ADAPTADA" : @activity.activity_type,
          subtitle: @activity.title,
          variant: :official
        )

        draw_identification(document)
        draw_student_line(document)
        draw_instructions(document)
        draw_questions(document)
        draw_footer(document)
      end

      pdf.render
    ensure
      @letterhead.cleanup
    end

    private

    def draw_identification(pdf)
      course_name = @lesson.course&.name.presence || "—"
      lesson_date =
        if @lesson.lesson_date.present?
          I18n.l(@lesson.lesson_date, format: :default)
        else
          "____/____/________"
        end

      rows = [
        [
          identification_cell("Professor(a)", @professor.name.presence || @professor.email),
          identification_cell("Disciplina", course_name)
        ],
        [
          identification_cell("Turma", @classroom.name),
          identification_cell("Data", lesson_date)
        ],
        [
          identification_cell("Bimestre", @activity.bimester_label),
          identification_cell("Valor", score_label)
        ]
      ]

      if @activity.adapted?
        rows << [
          identification_cell("Adaptação", @activity.adaptation_kind_label.presence || "Adaptada"),
          identification_cell(
            "Atividade da turma",
            @activity.parent_activity&.title.presence || "—"
          )
        ]
      end

      pdf.table(
        rows,
        width: pdf.bounds.width,
        cell_style: {
          borders: [:bottom],
          border_color: "D9E2F3",
          padding: [6, 4],
          size: 10,
          inline_format: true
        }
      )

      pdf.move_down 12
    end

    def identification_cell(label, value)
      { content: "<b>#{label}:</b> #{value}" }
    end

    def score_label
      if @activity.maximum_score.present?
        format("%.1f", @activity.maximum_score.to_f).tr(".", ",")
      else
        "—"
      end
    end

    def draw_student_line(pdf)
      pdf.fill_color "20263D"
      pdf.text(
        "Aluno(a): ________________________________  Nº: ________  Nota: ________",
        size: 10
      )
      pdf.move_down 12
    end

    def draw_instructions(pdf)
      body = @activity.instructions.to_s.strip
      return if body.blank?

      pdf.fill_color "1F4E79"
      pdf.text "Instruções", size: 11, style: :bold
      pdf.move_down 4

      pdf.fill_color "20263D"
      pdf.stroke_color "D9E2F3"
      pdf.bounding_box([0, pdf.cursor], width: pdf.bounds.width) do
        pdf.text body, size: 10, leading: 3
        pdf.move_down 6
      end

      pdf.move_down 8
    end

    def draw_questions(pdf)
      pdf.fill_color "1F4E79"
      pdf.text "Questões", size: 11, style: :bold
      pdf.move_down 8
      pdf.fill_color "20263D"

      questions = question_lines
      questions.each_with_index do |line, index|
        pdf.start_new_page if pdf.cursor < 72
        pdf.text numbered_line(line, index), size: 10, leading: 3
        pdf.move_down 22
        draw_answer_rule(pdf)
        pdf.move_down 10
      end
    end

    def question_lines
      lines = @activity.description.to_s.split(/\r?\n/).map(&:strip).reject(&:blank?)
      return lines if lines.any?

      Array.new(BLANK_QUESTION_COUNT) { "" }
    end

    def numbered_line(line, index)
      return line if line.match?(/\A\d+[\).\-\s]/)

      "#{index + 1}. #{line}".strip
    end

    def draw_answer_rule(pdf)
      pdf.stroke_color "C5CDD8"
      pdf.line_width 0.5
      2.times do
        pdf.stroke_horizontal_rule
        pdf.move_down 14
      end
      pdf.stroke_color "000000"
    end

    def draw_footer(pdf)
      pdf.number_pages(
        "Gerado pelo Maestro  ·  Página <page> de <total>",
        at: [0, 0],
        width: pdf.bounds.width,
        align: :center,
        size: 8,
        color: "777777"
      )
    end
  end
end
