module Documents
  class ActivitySheet
    BLANK_QUESTION_COUNT = 8

    def initialize(professor:, activity:, correction_url: nil, students: [], student_url: nil, mode: :student)
      @professor = professor
      @activity = activity
      @lesson = activity.lesson
      @classroom = @lesson.classroom
      @correction_url = correction_url
      @students = Array(students)
      @student_url = student_url
      @mode = mode.to_s == "answer_key" ? :answer_key : :student
      @letterhead = Letterhead.new(professor)
      @qr = QrMark.new(correction_url)
      @assigner = Activities::ExamAssigner.new(activity)
      @image_tempfiles = []
    end

    def render
      pdf = Prawn::Document.new(
        page_size: "A4",
        page_layout: :portrait,
        margin: 28,
        info: {
          Title: "#{@activity.activity_type} - #{@activity.title}",
          Author: @professor.name.presence || "Maestro"
        }
      ) do |document|
        Documents::PdfFont.apply(document)
        unless personalized_exams?
          @letterhead.draw(
            document,
            title: sheet_heading,
            subtitle: @activity.title,
            variant: :official
          )
        end

        if answer_key?
          draw_identification(document)
          draw_instructions(document)
          draw_professor_keys(document)
        elsif personalized_exams?
          draw_personalized_exams(document)
        else
          draw_identification(document)
          draw_student_line(document)
          draw_instructions(document)
          draw_questions(document)
          draw_omr_card(document)
        end
        draw_footer(document)
      end

      pdf.render
    ensure
      @letterhead.cleanup
      @qr.cleanup
      Array(@image_tempfiles).each do |file|
        file.close
        file.unlink
      rescue StandardError
        nil
      end
    end

    private

    def assembled_items
      @assembled_items ||= @activity.activity_questions.to_a
    end

    def answer_key?
      @mode == :answer_key
    end

    def student_copy?
      !answer_key?
    end

    def personalized_exams?
      student_copy? && assembled_items.any? && @students.any?
    end

    def sheet_heading
      base = @activity.adapted? ? "#{@activity.activity_type} · ADAPTADA" : @activity.activity_type
      answer_key? ? "Gabarito · #{base}" : base
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
      if item.bncc_skill.present?
        pdf.fill_color "707891"
        pdf.text "BNCC: #{item.bncc_skill}", size: 8
        pdf.fill_color "20263D"
      end
      draw_item_image(pdf, item)
      pdf.move_down 6

      if item.objective?
        item.choice_pairs.each do |letter, text|
          pdf.text "#{letter}) #{text}", size: 10, leading: 2
        end
        if answer_key?
          pdf.move_down 4
          pdf.fill_color "1F4E79"
          pdf.text "Gabarito: #{item.correct_letter}  ·  #{format('%.1f', item.points).tr('.', ',')} pt", size: 9, style: :bold
          pdf.fill_color "20263D"
        end
        pdf.move_down 10
      else
        pdf.move_down 8
        draw_answer_rule(pdf)
        pdf.move_down 8
      end
    end

    def draw_item_image(pdf, item)
      file = question_image_file(item.image)
      return unless file

      pdf.start_new_page if pdf.cursor < 120
      pdf.move_down 3
      pdf.image file.path, fit: [pdf.bounds.width * 0.55, 110]
      pdf.move_down 4
    rescue StandardError
      nil
    end

    def question_image_file(attachment)
      return unless attachment&.attached?

      ext = attachment.content_type.to_s.include?("png") ? ".png" : ".jpg"
      tempfile = Tempfile.new(["maestro-question", ext])
      tempfile.binmode
      tempfile.write(attachment.blob.download)
      tempfile.flush
      @image_tempfiles << tempfile
      tempfile
    rescue StandardError
      nil
    end

    def draw_omr_card(pdf, student: nil, presented: nil)
      rows = omr_rows(presented)
      return if rows.empty?

      pdf.start_new_page
      draw_omr_banner(pdf, student)

      layout = omr_layout_for(rows.size)
      top = pdf.cursor
      url = omr_qr_url(student)
      box_left = 0
      box_width = pdf.bounds.width
      padding = 10
      qr_size = url.present? ? layout[:qr_size] : 0
      single = layout[:columns] == 1 && qr_size.positive?

      if single
        grid_left = padding + qr_size + 14
        grid_width = box_width - grid_left - padding
        grid_top = top - padding
        @qr.draw(pdf, size: qr_size, url: url, at: [padding, grid_top])
      else
        if qr_size.positive?
          @qr.draw(pdf, size: qr_size, url: url, at: [box_width - padding - qr_size, top])
          pdf.move_cursor_to(top - qr_size - 8)
          top = pdf.cursor
        end
        grid_left = padding
        grid_width = box_width - (padding * 2)
        grid_top = top - 4
      end

      grid_height = draw_omr_grid(
        pdf,
        rows,
        left: grid_left,
        top: grid_top,
        width: grid_width,
        layout: layout
      )
      box_height = if single
                     [qr_size, grid_height].max + (padding * 2)
                   else
                     (top - (grid_top - grid_height)) + 8
                   end

      pdf.stroke_color "000000"
      pdf.line_width 1.1
      pdf.stroke_rectangle [box_left, top + 2], box_width, box_height
      pdf.move_cursor_to(top + 2 - box_height - 10)
      pdf.fill_color "444444"
      pdf.text "Pinte um círculo por questão. Não amasse o cartão.", size: 8
    end

    def draw_personalized_exams(pdf)
      @students.each_with_index do |student, index|
        pdf.start_new_page if index.positive?
        @letterhead.draw(
          pdf,
          title: sheet_heading,
          subtitle: @activity.title,
          variant: :official
        )
        draw_named_header(pdf, student)
        presented = @assigner.presented_for(student)
        presented.each do |row|
          pdf.start_new_page if pdf.cursor < 72
          draw_presented_item(pdf, row, show_key: false)
        end
        draw_omr_card(pdf, student: student, presented: presented)
      end
    end

    def draw_professor_keys(pdf)
      assignments = @activity.exam_assignments.includes(:student).order(:slot)
      if assignments.none?
        draw_questions(pdf)
        return
      end

      assignments.group_by(&:slot).each do |slot, rows|
        pdf.start_new_page if pdf.cursor < 90
        pdf.fill_color "1F4E79"
        pdf.text "Chave da folha #{slot} · só o professor", size: 11, style: :bold
        pdf.move_down 4
        pdf.fill_color "707891"
        pdf.text rows.map { |row| row.student.name }.join("  ·  "), size: 9
        pdf.move_down 10
        pdf.fill_color "20263D"
        @assigner.present(rows.first).each do |presented|
          pdf.start_new_page if pdf.cursor < 110
          draw_presented_item(pdf, presented, show_key: true)
        end
      end
    end

    def draw_named_header(pdf, student)
      meta = [
        @classroom.name,
        @lesson.course&.name,
        score_label
      ].compact.join("  ·  ")

      pdf.fill_color "20263D"
      pdf.text student.name.to_s, size: 11, style: :bold
      pdf.fill_color "707891"
      pdf.text meta, size: 8
      pdf.move_down 10
    end

    def draw_presented_item(pdf, presented, show_key:)
      item = presented.item
      pdf.fill_color "20263D"
      pdf.text "#{presented.number}. #{item.prompt}", size: 9, leading: 2, inline_format: false
      if show_key && item.bncc_skill.present?
        pdf.fill_color "707891"
        pdf.text "BNCC: #{item.bncc_skill}", size: 7
        pdf.fill_color "20263D"
      end
      draw_item_image(pdf, item)

      if item.objective?
        pdf.move_down 3
        presented.pairs.each do |letter, text|
          pdf.text "#{letter}) #{text}", size: 9, leading: 1.5
        end
        if show_key
          pdf.move_down 2
          pdf.fill_color "1F4E79"
          pdf.text "Gabarito: #{presented.printed_correct}  ·  #{format('%.1f', item.points).tr('.', ',')} pt", size: 8, style: :bold
          pdf.fill_color "20263D"
        end
        pdf.move_down 6
      else
        pdf.move_down 4
        draw_answer_rule(pdf)
        pdf.move_down 4
      end
    end

    def draw_omr_banner(pdf, student)
      pdf.fill_color "000000"
      pdf.text omr_banner_title, size: 11, style: :bold, align: :center
      pdf.move_down 8
      if student
        pdf.text student.name.to_s, size: 10, style: :bold
      else
        pdf.text "Aluno(a): ________________________________  Nº: ________", size: 10
      end
      pdf.move_down 12
    end

    def omr_banner_title
      [
        @classroom.name,
        @lesson.course&.name.presence,
        @activity.title
      ].compact.join("  ·  ")
    end

    def omr_qr_url(student)
      return @student_url.call(student).to_s if student && @student_url

      @correction_url.to_s
    end

    def omr_rows(presented)
      if presented
        presented.filter_map do |row|
          next unless row.item.objective?

          { number: row.number, letters: row.pairs.map(&:first) }
        end
      else
        assembled_items.each_with_index.filter_map do |item, index|
          next unless item.objective?

          letters = item.choice_pairs.map(&:first)
          letters = Question::LETTERS if letters.blank?
          { number: index + 1, letters: letters }
        end
      end
    end

    def omr_letters(rows)
      rows.flat_map { |row| row[:letters] }.uniq.sort.presence || Question::LETTERS
    end

    def omr_layout_for(count)
      if count <= 16
        { columns: 1, qr_size: 210, row_h: 22, radius: 7, fiducial: 12 }
      elsif count <= 36
        { columns: 2, qr_size: 88, row_h: 18, radius: 6, fiducial: 11 }
      else
        { columns: 3, qr_size: 72, row_h: 16, radius: 5, fiducial: 10 }
      end
    end

    def draw_omr_grid(pdf, rows, left:, top:, width:, layout:)
      letters = omr_letters(rows)
      columns = layout[:columns]
      fiducial = layout[:fiducial]
      row_h = layout[:row_h]
      per_col = (rows.size.to_f / columns).ceil
      col_w = width / columns.to_f

      pdf.fill_color "000000"
      pdf.fill_rectangle [left, top], fiducial, fiducial
      pdf.fill_rectangle [left + width - fiducial, top], fiducial, fiducial

      header_top = top - fiducial - 2
      tallest = 0
      columns.times do |column|
        slice = rows.slice(column * per_col, per_col) || []
        next if slice.empty?

        x = left + (column * col_w)
        height = draw_omr_column(
          pdf,
          slice,
          letters: letters,
          left: x,
          top: header_top,
          width: col_w - 8,
          row_h: row_h,
          radius: layout[:radius]
        )
        tallest = height if height > tallest
      end

      fiducial + 2 + tallest
    end

    def draw_omr_column(pdf, rows, letters:, left:, top:, width:, row_h:, radius:)
      label_w = 32
      usable = [width - label_w, 20].max
      step = usable / [letters.size, 1].max
      radius = [radius, (step / 2) - 1.5].min
      header_y = top

      letters.each_with_index do |letter, index|
        cx = left + label_w + (index * step) + (step / 2)
        pdf.fill_color "000000"
        pdf.text_box letter.to_s.downcase,
                     at: [cx - 8, header_y],
                     width: 16,
                     height: 12,
                     size: 9,
                     align: :center,
                     style: :bold
      end

      y = header_y - 16
      rows.each do |row|
        pdf.fill_color "000000"
        pdf.text_box "Q.#{row[:number]}",
                     at: [left, y + 4],
                     width: label_w,
                     height: 14,
                     size: 9,
                     style: :bold
        letters.each_with_index do |_letter, index|
          cx = left + label_w + (index * step) + (step / 2)
          cy = y - 2
          pdf.stroke_color "000000"
          pdf.line_width 0.9
          pdf.stroke_circle [cx, cy], radius
        end
        y -= row_h
      end

      (header_y - y) + 6
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
