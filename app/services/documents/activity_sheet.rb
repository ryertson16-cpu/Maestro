module Documents
  class ActivitySheet
    BLANK_QUESTION_COUNT = 8

    def initialize(professor:, activity:, correction_url: nil, students: [], student_url: nil)
      @professor = professor
      @activity = activity
      @lesson = activity.lesson
      @classroom = @lesson.classroom
      @correction_url = correction_url
      @students = Array(students)
      @student_url = student_url
      @letterhead = Letterhead.new(professor)
      @qr = QrMark.new(correction_url)
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
        draw_answer_sheet(document) if assembled_items.any?
        draw_student_sheets(document) if assembled_items.any? && @students.any?
        draw_footer(document)
      end

      pdf.render
    ensure
      @letterhead.cleanup
      @qr.cleanup
    end

    private

    def assembled_items
      @assembled_items ||= @activity.activity_questions.to_a
    end

    def draw_identification(pdf)
      course_name = @lesson.course&.name.presence || "—"
      lesson_date =
        if @lesson.lesson_date.present?
          I18n.l(@lesson.lesson_date, format: :default)
        else
          "____/____/________"
        end

      table_width = @correction_url.present? ? pdf.bounds.width - 78 : pdf.bounds.width

      if @correction_url.present?
        qr_top = pdf.cursor
        pdf.float do
          pdf.bounding_box([pdf.bounds.width - 70, qr_top], width: 70, height: 78) do
            @qr.draw(pdf, size: 64)
            pdf.fill_color "707891"
            pdf.text_box "QR correcao", at: [0, 10], width: 70, height: 10, size: 7, align: :center
          end
        end
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
        width: table_width,
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

      if assembled_items.any?
        assembled_items.each_with_index do |item, index|
          pdf.start_new_page if pdf.cursor < 110
          draw_assembled_item(pdf, item, index)
        end
      else
        question_lines.each_with_index do |line, index|
          pdf.start_new_page if pdf.cursor < 72
          pdf.text numbered_line(line, index), size: 10, leading: 3
          pdf.move_down 22
          draw_answer_rule(pdf)
          pdf.move_down 10
        end
      end
    end

    def draw_assembled_item(pdf, item, index)
      pdf.fill_color "20263D"
      pdf.text "#{index + 1}. #{item.prompt}", size: 10, leading: 3, inline_format: false
      pdf.move_down 6

      if item.objective?
        item.choice_pairs.each do |letter, text|
          pdf.text "#{letter}) #{text}", size: 10, leading: 2
        end
        pdf.move_down 10
      else
        pdf.move_down 8
        draw_answer_rule(pdf)
        pdf.move_down 8
      end
    end

    def draw_answer_sheet(pdf)
      pdf.start_new_page
      @letterhead.draw(
        pdf,
        title: "Folha de respostas",
        subtitle: @activity.title,
        variant: :official
      )

      pdf.fill_color "20263D"
      pdf.text(
        "Aluno(a): ________________________________  Nº: ________",
        size: 10
      )
      pdf.move_down 6
      pdf.text(
        "Pinte um circulo por questao objetiva. O professor abre a camera do celular no QR do gabarito.",
        size: 9
      )
      pdf.move_down 14

      if @correction_url.present?
        mark_top = pdf.cursor
        @qr.draw(pdf, size: 72)
        pdf.move_cursor_to(mark_top - 8)
      end

      assembled_items.each_with_index do |item, index|
        pdf.start_new_page if pdf.cursor < 36
        label = "#{index + 1}."
        pdf.text_box label, at: [0, pdf.cursor], width: 28, height: 16, size: 10, style: :bold

        if item.objective?
          draw_bubbles(pdf, item)
        else
          pdf.fill_color "20263D"
          pdf.text_box "Discursiva - #{format('%.1f', item.points).tr('.', ',')} pt",
                       at: [32, pdf.cursor],
                       width: 300,
                       height: 16,
                       size: 9
        end
        pdf.move_down 22
      end
    end

    def draw_student_sheets(pdf)
      @students.each do |student|
        url = @student_url&.call(student).to_s
        pdf.start_new_page
        @letterhead.draw(
          pdf,
          title: "Folha de respostas",
          subtitle: @activity.title,
          variant: :official
        )

        top = pdf.cursor
        if url.present?
          pdf.float do
            pdf.bounding_box([pdf.bounds.width - 78, top], width: 78, height: 86) do
              @qr.draw(pdf, size: 72, url: url)
            end
          end
        end

        pdf.fill_color "20263D"
        pdf.text student.name.to_s, size: 12, style: :bold
        pdf.move_down 4
        pdf.text "#{@classroom.name}  ·  camera do celular no QR", size: 9
        pdf.move_down 16

        assembled_items.each_with_index do |item, index|
          pdf.start_new_page if pdf.cursor < 36
          pdf.text_box "#{index + 1}.", at: [0, pdf.cursor], width: 28, height: 16, size: 10, style: :bold
          if item.objective?
            draw_bubbles(pdf, item)
          else
            pdf.text_box "Discursiva - #{format('%.1f', item.points).tr('.', ',')} pt",
                         at: [32, pdf.cursor],
                         width: 300,
                         height: 16,
                         size: 9
          end
          pdf.move_down 22
        end
      end
    end

    def draw_bubbles(pdf, item)
      letters = item.choice_pairs.map(&:first)
      letters = Question::LETTERS.first(4) if letters.blank?

      letters.each_with_index do |letter, index|
        x = 36 + (index * 42)
        y = pdf.cursor - 2
        pdf.stroke_color "1F4E79"
        pdf.line_width 0.8
        pdf.stroke_circle [x, y - 6], 8
        pdf.fill_color "20263D"
        pdf.draw_text letter, at: [x - 3, y - 9], size: 8
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
