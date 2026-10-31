module Documents
  class ExamGradesReport
    def initialize(professor:, activity:, result:)
      @professor = professor
      @activity = activity
      @lesson = activity.lesson
      @classroom = @lesson.classroom
      @result = result
      @letterhead = Letterhead.new(professor)
    end

    def render
      pdf = Prawn::Document.new(page_size: "A4", margin: 36) do |document|
        Documents::PdfFont.apply(document)
        @letterhead.draw(
          document,
          title: "Notas da prova",
          subtitle: @activity.title,
          variant: :official
        )
        document.fill_color "707891"
        document.text(
          [ @classroom.name, @lesson.course&.name, @activity.activity_type ].compact.join(" · "),
          size: 10
        )
        document.move_down 12
        document.fill_color "20263D"
        document.text "Média da turma: #{fmt(@result.average)}   ·   #{@result.pass_count} de #{@result.students.size} com nota 7 ou mais", size: 10
        document.move_down 14

        rows = [ [ "Aluno", "Acertos", "Nota" ] ]
        @result.readings.each do |row|
          score = row.submission&.score
          rows << [
            row.student.name,
            row.objective_count.positive? ? "#{row.hits} de #{row.objective_count}" : "—",
            score.present? ? fmt(score) : "—"
          ]
        end

        document.table(rows, header: true, width: document.bounds.width) do |table|
          table.row(0).font_style = :bold
          table.row(0).background_color = "EEECFF"
          table.cells.size = 9
          table.cells.padding = 6
          table.cells.border_color = "D9D7F2"
        end
      end

      pdf.render
    ensure
      @letterhead.cleanup
    end

    private

    def fmt(value)
      format("%.1f", value.to_f).tr(".", ",")
    end
  end
end
