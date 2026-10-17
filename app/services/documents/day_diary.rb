require "prawn/table"

module Documents
  class DayDiary
    STATUS_LABELS = {
      "present" => "Presente",
      "absent" => "Falta",
      "justified" => "Justificada",
      "late" => "Atraso"
    }.freeze

    def initialize(professor:, classroom:, date:, lessons:, enrollments:, records_by_lesson:)
      @professor = professor
      @classroom = classroom
      @date = date
      @lessons = Array(lessons)
      @enrollments = Array(enrollments)
      @records_by_lesson = records_by_lesson || {}
      @letterhead = Letterhead.new(professor)
    end

    def render
      pdf = Prawn::Document.new(
        page_size: "A4",
        page_layout: :portrait,
        margin: 36,
        info: {
          Title: "Diário de classe - #{@classroom.name} - #{@date.iso8601}",
          Author: @professor.name.presence || "Maestro"
        }
      ) do |document|
        document.font_size 9
        @lessons.each_with_index do |lesson, index|
          if index.positive?
            document.start_new_page
          end
          @letterhead.draw(
            document,
            title: "DIÁRIO DE CLASSE",
            subtitle: "#{@classroom.name} · #{I18n.l(@date)}",
            variant: :official
          )
          draw_lesson(document, lesson)
        end

        if @lessons.blank?
          @letterhead.draw(
            document,
            title: "DIÁRIO DE CLASSE",
            subtitle: "#{@classroom.name} · #{I18n.l(@date)}",
            variant: :official
          )
          document.text "Não há aula registrada neste dia.", size: 10
        end
      end

      pdf.render
    ensure
      @letterhead.cleanup
    end

    private

    def draw_lesson(pdf, lesson)
      pdf.fill_color "1F4E79"
      pdf.text lesson.siage_time_slot.presence || "Tempo", size: 12, style: :bold
      pdf.move_down 4
      pdf.fill_color "20263D"
      pdf.text "Disciplina: #{lesson.course&.name.presence || "Não informada"}", size: 10
      pdf.text "Tema: #{lesson.theme}", size: 10
      if lesson.content.present?
        pdf.move_down 6
        pdf.text "Conteúdo", size: 10, style: :bold
        pdf.text lesson.content.to_s, size: 9, leading: 2
      end
      if lesson.objective.present?
        pdf.move_down 6
        pdf.text "Objetivo", size: 10, style: :bold
        pdf.text lesson.objective.to_s, size: 9, leading: 2
      end
      if lesson.skills.present?
        pdf.move_down 6
        pdf.text "Habilidades", size: 10, style: :bold
        pdf.text lesson.skills.to_s, size: 9, leading: 2
      end

      pdf.move_down 12
      pdf.text "Frequência", size: 10, style: :bold
      pdf.move_down 6

      records = @records_by_lesson[lesson.id] || {}
      rows = [["Aluno", "Situação"]]
      @enrollments.each do |enrollment|
        status = records[enrollment.id]&.status.presence || "present"
        name = enrollment.student.name
        tag = enrollment.caderno_tag
        name = "#{name} (#{tag})" if tag.present?
        rows << [name, STATUS_LABELS.fetch(status.to_s, status.to_s)]
      end

      pdf.table(rows, header: true, width: pdf.bounds.width) do |table|
        table.row(0).font_style = :bold
        table.row(0).background_color = "E8EEF6"
        table.cells.size = 8
        table.cells.padding = [5, 6]
        table.column(1).width = 90
      end
      pdf.fill_color "000000"
    end
  end
end
