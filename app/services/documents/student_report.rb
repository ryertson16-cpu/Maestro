module Documents
  class StudentReport
    TONE_COLORS = {
      "danger" => { background: "FFF0F3", text: "D84D68" },
      "warning" => { background: "FFF8E5", text: "B47B10" },
      "late" => { background: "FFF1E6", text: "C45E12" },
      "ok" => { background: "E7F8F1", text: "159570" }
    }.freeze

    def initialize(professor:, student:, current_enrollments:, current_classroom:, attendance_records:, activity_rows:, grade_history:, council_note:, current_bimester:)
      @professor = professor
      @student = student
      @current_enrollments = current_enrollments
      @current_classroom = current_classroom
      @attendance_records = attendance_records
      @activity_rows = activity_rows
      @grade_history = grade_history || { activities: [], bimesters: [] }
      @council_note = council_note
      @current_bimester = current_bimester
      @month = Date.current.beginning_of_month
      @letterhead = Letterhead.new(professor)
    end

    def render
      pdf = Prawn::Document.new(
        page_size: "A4",
        page_layout: :portrait,
        margin: 36,
        info: {
          Title: "Relatório individual - #{@student.name}",
          Author: @professor.respond_to?(:name) ? @professor.name : "Maestro"
        }
      ) do |document|
        document.font_size 9

        @letterhead.draw(
          document,
          title: "RELATÓRIO INDIVIDUAL DO ALUNO",
          subtitle: @student.name
        )

        draw_student_information(document)
        draw_situation(document)
        draw_attendance_recorte(document)
        draw_pendencies(document)
        draw_current_bimester_grades(document)
        draw_council_note(document)
        draw_attendance_detail(document)
        draw_activities(document)
        draw_grade_comparison(document)
        draw_footer(document)
      end

      pdf.render
    ensure
      @letterhead.cleanup
    end

    private

    def draw_student_information(pdf)
      draw_section_title(pdf, "Informações do aluno")
      draw_student_photo(pdf)

      classrooms = @current_enrollments.filter_map { |enrollment| enrollment.classroom&.name }
      courses = @current_enrollments.filter_map do |enrollment|
        classroom = enrollment.classroom
        classroom.school_course&.name || classroom.course&.name
      end.uniq

      information = [
        ["Nome", @student.name],
        ["Matrícula", @student.registration_number.presence || "Não informado"],
        ["Série", series_label],
        [
          "Turma",
          classrooms.any? ? classrooms.join(", ") : "Não matriculado em uma turma ativa"
        ],
        ["Curso", courses.any? ? courses.join(", ") : "Não informado"],
        ["Disciplina", discipline_label],
        ["Data de emissão", I18n.l(Date.current, format: "%d/%m/%Y")]
      ]

      draw_two_column_table(pdf, information)
      pdf.move_down 14
    end

    def draw_situation(pdf)
      draw_section_title(pdf, "Situação atual")

      tags = monitoring_alert&.tags.presence || [{ tone: "ok", label: "Em dia" }]
      tags.each_slice(2) do |pair|
        cells = pair.map do |tag|
          colors = TONE_COLORS.fetch(tag[:tone].to_s, TONE_COLORS["ok"])
          {
            content: tag[:label],
            background_color: colors[:background],
            text_color: colors[:text],
            font_style: :bold,
            align: :center,
            valign: :center,
            borders: [],
            padding: [5, 7]
          }
        end

        column_width = pdf.bounds.width / pair.size
        pdf.table(
          [cells],
          column_widths: Array.new(pair.size, column_width),
          cell_style: { size: 7 }
        )
        pdf.move_down 4
      end
      pdf.move_down 10
    end

    def draw_attendance_recorte(pdf)
      month_label = I18n.l(@month, format: "%B de %Y").capitalize
      draw_section_title(pdf, "Frequência — #{month_label}")

      snapshot = attendance_snapshot(month_records)
      rows = [
        ["Frequência do mês", format_percentage(snapshot[:percentage])],
        ["Presenças", snapshot[:present].to_s],
        ["Faltas", snapshot[:absent].to_s],
        ["Justificadas", snapshot[:justified].to_s],
        ["Atrasos", snapshot[:late].to_s],
        ["Atrasos no mês", format_percentage(snapshot[:late_ratio])]
      ]

      bimester_records = bimester_month_overlap_records
      if bimester_records.any?
        bimester_snapshot = attendance_snapshot(bimester_records)
        rows << [
          "Frequência do #{@current_bimester}º bimestre",
          format_percentage(bimester_snapshot[:percentage])
        ]
      end

      draw_two_column_table(pdf, rows)
      pdf.move_down 4
      pdf.fill_color "666666"
      pdf.text "Atraso não é falta: o percentual de frequência desconta só as ausências.", size: 8
      pdf.fill_color "000000"
      pdf.move_down 14
    end

    def draw_pendencies(pdf)
      draw_section_title(pdf, "Pendências")

      pending = Array(monitoring_alert&.pending_activities)
      unscored = Array(monitoring_alert&.unscored_activities)

      if pending.empty? && unscored.empty?
        pdf.text "Nenhuma pendência de entrega ou de nota lançada."
        pdf.move_down 14
        return
      end

      if pending.any?
        pdf.text "Atividades não entregues", style: :bold, size: 9
        pdf.move_down 4
        pending.each do |item|
          activity = item[:activity]
          due = activity.due_date.present? ? I18n.l(activity.due_date, format: "%d/%m/%Y") : "sem data"
          pdf.text "• #{activity.title} (limite: #{due})", size: 8
        end
        pdf.move_down 8
      end

      if unscored.any?
        pdf.text "Notas não lançadas", style: :bold, size: 9
        pdf.move_down 4
        unscored.each do |item|
          activity = item[:activity]
          pdf.text "• #{activity.title} (#{activity.bimester}º bimestre)", size: 8
        end
      end

      pdf.move_down 14
    end

    def draw_current_bimester_grades(pdf)
      draw_section_title(pdf, "Notas do #{@current_bimester}º bimestre")

      item = Array(@grade_history[:bimesters]).find do |bimester|
        bimester[:bimester].to_i == @current_bimester.to_i
      end

      if item.blank? || (item[:score].blank? && item[:class_average].blank?)
        pdf.text "Sem média lançada neste bimestre."
        pdf.move_down 14
        return
      end

      rows = [
        ["Média do aluno", format_optional_score(item[:score])],
        ["Média da turma", format_optional_score(item[:class_average])],
        ["Diferença", difference_label(item[:score], item[:class_average])]
      ]

      draw_two_column_table(pdf, rows)
      pdf.move_down 14
    end

    def draw_council_note(pdf)
      return if @council_note.blank?

      draw_section_title(pdf, "Observação do conselho")
      pdf.text @council_note.body.to_s, size: 9
      pdf.move_down 14
    end

    def draw_attendance_detail(pdf)
      draw_section_title(pdf, "Frequência do mês por tempo")

      records = month_records.sort_by do |record|
        [
          record.attendance_date,
          slot_number(record.lesson&.siage_time_slot),
          record.id.to_i
        ]
      end.reverse

      if records.empty?
        pdf.text "Nenhum registro de frequência neste mês."
        pdf.move_down 14
        return
      end

      rows = [["Data", "Tempo", "Situação"]]
      records.each do |record|
        rows << [
          format_date(record.attendance_date),
          record.lesson&.siage_time_slot.presence || "—",
          attendance_status_label(record.status)
        ]
      end

      draw_data_table(pdf, rows, widths: [120, 200, 170])
      pdf.move_down 14
    end

    def draw_activities(pdf)
      draw_section_title(pdf, "Atividades")

      if @activity_rows.blank?
        pdf.text "Nenhuma atividade encontrada."
        pdf.move_down 14
        return
      end

      rows = [["Atividade", "Disciplina", "Bimestre", "Nota", "Peso", "Status"]]

      @activity_rows.each do |row|
        activity = row[:activity]
        submission = row[:submission]
        score =
          if NumericScore.recorded?(submission&.score)
            format_score(submission.score)
          else
            "—"
          end

        rows << [
          activity.adapted? ? "#{activity.title} (adaptada)" : activity.title.to_s,
          activity_discipline_name(activity),
          "#{activity.bimester}º",
          score,
          format_score(activity.weight),
          activity_status(row)
        ]
      end

      draw_data_table(pdf, rows, widths: [145, 95, 55, 50, 45, 100], font_size: 7)
      pdf.move_down 14
    end

    def draw_grade_comparison(pdf)
      activities = Array(@grade_history[:activities]).select do |item|
        item[:score].present? || item[:class_average].present?
      end
      bimesters = Array(@grade_history[:bimesters]).select do |item|
        item[:score].present? || item[:class_average].present?
      end

      return if activities.empty? && bimesters.empty?

      draw_section_title(pdf, "Comparativo com a turma")

      if activities.any?
        pdf.fill_color "666666"
        pdf.text "Só entram atividades com nota do aluno ou média da turma.", size: 8
        pdf.fill_color "000000"
        pdf.move_down 6

        rows = [["Atividade", "Disciplina", "Bimestre", "Aluno", "Turma", "Diferença"]]
        activities.each do |item|
          rows << [
            item[:title].to_s,
            item[:discipline].to_s,
            "#{item[:bimester]}º",
            format_optional_score(item[:score]),
            format_optional_score(item[:class_average]),
            difference_label(item[:score], item[:class_average])
          ]
        end

        draw_data_table(pdf, rows, widths: [145, 90, 50, 55, 55, 55], font_size: 7)
        pdf.move_down 12
      end

      return if bimesters.empty?

      pdf.fill_color "666666"
      pdf.text "Médias ponderadas dos bimestres com nota.", size: 8
      pdf.fill_color "000000"
      pdf.move_down 6

      rows = [["Bimestre", "Aluno", "Turma", "Diferença"]]
      bimesters.each do |item|
        rows << [
          item[:label].to_s,
          format_optional_score(item[:score]),
          format_optional_score(item[:class_average]),
          difference_label(item[:score], item[:class_average])
        ]
      end

      draw_data_table(pdf, rows, widths: [180, 110, 110, 90])
    end

    def draw_student_photo(pdf)
      return unless @student.photo.attached?

      photo_data = @student.photo.download
      pdf.image StringIO.new(photo_data),
                at: [pdf.bounds.right - 90, pdf.cursor],
                width: 72,
                height: 72,
                fit: :shrink_to_fit
      pdf.move_down 82
    rescue StandardError
      nil
    end

    def series_label
      recorded = @student.series.to_s.strip
      return recorded if recorded.present?

      classroom_names.each do |name|
        match = name.to_s.match(/(\d+)\s*ª/) || name.to_s.match(/(\d+)\s*a(?=[[:space:]]|\z)/i)
        return "#{match[1]}ª Série" if match
      end

      "Não informada"
    end

    def classroom_names
      names = @current_enrollments.filter_map { |enrollment| enrollment.classroom&.name }
      names << @current_classroom.name if @current_classroom&.name.present?
      names.uniq
    end

    def discipline_label
      names = []
      names << @current_classroom&.course&.name
      names.concat(
        @current_enrollments.filter_map { |enrollment| enrollment.classroom&.course&.name }
      )
      names.concat(
        Array(@activity_rows).filter_map { |row| activity_discipline_name(row[:activity]) }
      )

      names = names.map { |name| name.to_s.strip }.uniq
      names.reject! { |name| name.blank? || name == "Não informada" }
      names.any? ? names.join(", ") : "Não informada"
    end

    def monitoring_alert
      return if @current_classroom.blank?

      @monitoring_alert ||= Monitoring::AlertReport
                            .new(
                              professor: @professor,
                              classroom: @current_classroom,
                              month: @month
                            )
                            .student_rows
                            .find { |row| row.student.id == @student.id }
    end

    def month_records
      @month_records ||= begin
        records = @attendance_records.select do |record|
          record.attendance_date.beginning_of_month == @month
        end

        records = filter_classroom_records(records)
        records
      end
    end

    def bimester_month_overlap_records
      window = Siage.window_for_bimester(@current_bimester)
      return [] if window.blank?

      first_day, last_day, = window
      filter_classroom_records(
        @attendance_records.select do |record|
          record.attendance_date >= first_day && record.attendance_date <= last_day
        end
      )
    end

    def filter_classroom_records(records)
      return records if @current_classroom.blank?

      records.select do |record|
        record.classroom&.id == @current_classroom.id ||
          record.enrollment&.classroom_id == @current_classroom.id
      end
    end

    def attendance_snapshot(records)
      total = records.size
      absent = records.count(&:absent?)
      late = records.count(&:late?)

      {
        present: records.count(&:present?),
        absent: absent,
        justified: records.count(&:justified?),
        late: late,
        percentage: total.zero? ? nil : (((total - absent).to_f / total) * 100).round(1),
        late_ratio: total.zero? ? nil : ((late.to_f / total) * 100).round(1)
      }
    end

    def activity_status(row)
      submission = row[:submission]
      due = row[:due_date]
      overdue = due.present? && due <= Date.current
      scored = NumericScore.recorded?(submission&.score)

      if scored
        return "Entregue com atraso" if row[:status_key] == "delivered_late"

        return "Entregue"
      end

      return "Não entregue" if overdue && submission.blank?
      return "Sem nota lançada" if overdue

      "Em andamento"
    end

    def activity_discipline_name(activity)
      lesson = activity.lesson

      if lesson.respond_to?(:course) && lesson.course.present?
        lesson.course.name.to_s
      elsif lesson.respond_to?(:school_course) && lesson.school_course.present?
        lesson.school_course.name.to_s
      else
        "Não informada"
      end
    end

    def difference_label(student_score, class_average)
      return "—" unless student_score.present? && class_average.present?

      format_score(student_score.to_f - class_average.to_f)
    end

    def format_optional_score(value)
      NumericScore.recorded?(value) ? format_score(value) : "—"
    end

    def format_score(value)
      format("%.1f", value.to_f).tr(".", ",")
    end

    def format_percentage(value)
      value.present? ? "#{value}%" : "—"
    end

    def format_date(value)
      return "—" if value.blank?

      I18n.l(value.to_date, format: "%d/%m/%Y")
    end

    def attendance_status_label(status)
      case status.to_s
      when "present" then "Presente"
      when "absent" then "Ausente"
      when "justified" then "Falta justificada"
      when "late" then "Atrasado"
      else status.to_s.humanize
      end
    end

    def slot_number(slot)
      slot.to_s.scan(/\d+/).first.to_i
    end

    def draw_section_title(pdf, title)
      pdf.fill_color "1F4E79"
      pdf.text title, size: 12, style: :bold
      pdf.move_down 6
      pdf.fill_color "000000"
    end

    def draw_two_column_table(pdf, rows)
      pdf.table(
        rows,
        width: pdf.bounds.width,
        cell_style: {
          padding: [6, 8],
          borders: [:bottom],
          border_color: "D9E2F3",
          size: 9
        },
        column_widths: [180, pdf.bounds.width - 180]
      ) do |table|
        table.column(0).font_style = :bold
        table.column(0).text_color = "666666"
      end
    end

    def draw_data_table(pdf, rows, widths:, font_size: 8)
      pdf.table(
        rows,
        width: widths.sum,
        column_widths: widths,
        header: true,
        row_colors: %w[FFFFFF F4F7FA],
        cell_style: {
          padding: [5, 5],
          size: font_size,
          borders: [:bottom],
          border_color: "D9E2F3",
          valign: :center
        }
      ) do |table|
        table.row(0).background_color = "1F4E79"
        table.row(0).text_color = "FFFFFF"
        table.row(0).font_style = :bold
      end
    end

    def draw_footer(pdf)
      pdf.number_pages(
        "Página <page> de <total>",
        at: [pdf.bounds.right - 100, 0],
        align: :right,
        size: 8,
        color: "777777"
      )
    end
  end
end
