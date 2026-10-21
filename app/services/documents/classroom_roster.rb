require "prawn/table"

module Documents
  class ClassroomRoster
    def initialize(professor:, classroom:, enrollments:)
      @professor = professor
      @classroom = classroom
      @enrollments = Array(enrollments)
      @letterhead = Letterhead.new(professor)
    end

    def render
      pdf = Prawn::Document.new(
        page_size: "A4",
        page_layout: :portrait,
        margin: 36,
        info: {
          Title: "Relação de alunos - #{@classroom.name}",
          Author: @professor.name.presence || "Maestro"
        }
      ) do |document|
        document.font_size 9
        @letterhead.draw(
          document,
          title: "RELAÇÃO DE ALUNOS",
          subtitle: subtitle,
          variant: :official
        )
        draw_context(document)
        draw_names(document)
      end

      pdf.render
    ensure
      @letterhead.cleanup
    end

    private

    def subtitle
      [
        @classroom.name,
        @classroom.grade_level&.name,
        @classroom.school_year
      ].compact.join(" · ")
    end

    def draw_context(pdf)
      pdf.fill_color "20263D"
      course = @classroom.school_course&.name.presence || @classroom.course&.name
      lines = [
        ["Curso", course],
        ["Turno", @classroom.shift_label.presence],
        ["Alunos", @enrollments.size.to_s]
      ]
      lines.each do |label, value|
        next if value.blank?

        pdf.text "#{label}: #{value}", size: 10
      end
      pdf.move_down 12
    end

    def draw_names(pdf)
      pdf.fill_color "1F4E79"
      pdf.text "Alunos", size: 11, style: :bold
      pdf.move_down 8
      pdf.fill_color "20263D"

      if @enrollments.blank?
        pdf.text "Não há alunos com matrícula ativa nesta turma.", size: 10
        return
      end

      rows = [["Nº", "Nome"]]
      @enrollments.each_with_index do |enrollment, index|
        rows << [(index + 1).to_s, enrollment.student.name.to_s]
      end

      pdf.table(rows, header: true, width: pdf.bounds.width) do |table|
        table.row(0).font_style = :bold
        table.row(0).background_color = "E8EEF6"
        table.cells.size = 9
        table.cells.padding = [5, 6]
        table.column(0).width = 40
        table.column(0).align = :center
      end
      pdf.fill_color "000000"
    end
  end
end
