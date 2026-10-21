require "prawn/table"

module Documents
  class ActivityDeliveryReport
    STATUS_LABELS = {
      delivered: "Entregue",
      delivered_late: "Entregue com atraso",
      in_progress: "Em andamento",
      not_delivered: "Nao entregou"
    }.freeze

    def initialize(professor:, classroom:, activity:)
      @professor = professor
      @classroom = classroom
      @activity = activity
      @letterhead = Letterhead.new(professor)
      @rows = self.class.delivery_rows(classroom: classroom, activity: activity)
    end

    def render
      pdf = Prawn::Document.new(
        page_size: "A4",
        page_layout: :portrait,
        margin: 36,
        info: {
          Title: "Relatorio da atividade - #{@activity.title}",
          Author: @professor.name.presence || "Maestro"
        }
      ) do |document|
        document.font_size 9
        @letterhead.draw(
          document,
          title: "RELATORIO DA ATIVIDADE",
          subtitle: ascii(subtitle)
        )
        draw_context(document)
        draw_summary(document)
        draw_students(document)
      end

      pdf.render
    ensure
      @letterhead.cleanup
    end

    private

    def subtitle
      [
        @classroom.name,
        @activity.title,
        @activity.bimester_label
      ].compact.join(" · ")
    end

    def draw_context(pdf)
      pdf.fill_color "20263D"
      [
        ["Turma", @classroom.name],
        ["Atividade", @activity.title],
        ["Tipo", @activity.activity_type],
        ["Bimestre", @activity.bimester_label],
        ["Limite", format_date(@activity.due_date)],
        ["Peso", @activity.weight.to_s],
        ["Relatorio gerado em", format_date(Date.current)]
      ].each do |label, value|
        pdf.text ascii("#{label}: #{value}"), size: 10
      end
      pdf.move_down 12
    end

    def draw_summary(pdf)
      counts = Hash.new(0)
      @rows.each { |row| counts[row[:status]] += 1 }

      pdf.fill_color "1F4E79"
      pdf.text "Sintese", size: 11, style: :bold
      pdf.move_down 6
      pdf.fill_color "20263D"

      rows = [
        ["Alunos", "Em andamento", "Entregues", "Com atraso", "Nao entregou"],
        [
          @rows.size.to_s,
          counts[:in_progress].to_s,
          counts[:delivered].to_s,
          counts[:delivered_late].to_s,
          counts[:not_delivered].to_s
        ]
      ]

      pdf.table(rows, header: true, width: pdf.bounds.width) do |table|
        style_table(table)
        table.cells.align = :center
      end
      pdf.move_down 14
    end

    def draw_students(pdf)
      pdf.fill_color "1F4E79"
      pdf.text "Alunos", size: 11, style: :bold
      pdf.move_down 6
      pdf.fill_color "20263D"

      if @rows.empty?
        pdf.text "Nenhum aluno nesta atividade.", size: 10
        return
      end

      table_rows = [["N.", "Nome", "Situacao", "Data de recebimento"]]
      @rows.each_with_index do |row, index|
        table_rows << [
          (index + 1).to_s,
          ascii(row[:student].name),
          STATUS_LABELS.fetch(row[:status], row[:status].to_s),
          format_date(row[:submitted_on])
        ]
      end

      pdf.table(table_rows, header: true, width: pdf.bounds.width) do |table|
        style_table(table)
        table.column(0).width = 32
        table.column(0).align = :center
        table.column(2).width = 120
        table.column(3).width = 110
        table.column(3).align = :center
      end
    end

    def style_table(table)
      table.row(0).font_style = :bold
      table.row(0).background_color = "E8EEF6"
      table.cells.size = 9
      table.cells.padding = [5, 6]
    end

    def self.delivery_rows(classroom:, activity:)
      students = classroom.students.order(:name).to_a
      if activity.adapted?
        students = students.select { |student| activity.assigned_to?(student) }
      else
        students = students.reject { |student| activity.replacing_version_for(student).present? }
      end

      submissions = ActivitySubmission
                    .where(activity: activity, student_id: students.map(&:id))
                    .index_by(&:student_id)

      rank = {
        not_delivered: 0,
        in_progress: 1,
        delivered_late: 2,
        delivered: 3
      }

      students.map { |student|
        submission = submissions[student.id]
        status =
          if submission.present?
            submission.status
          elsif Date.current > activity.due_date
            :not_delivered
          else
            :in_progress
          end

        {
          student: student,
          status: status,
          submitted_on: submission&.submitted_on
        }
      }.sort_by { |row| [rank.fetch(row[:status], 9), row[:student].name.to_s] }
    end

    def format_date(value)
      return "-" if value.blank?

      value.to_date.strftime("%d/%m/%Y")
    end

    def ascii(value)
      value.to_s
           .unicode_normalize(:nfkd)
           .gsub(/\p{M}/, "")
           .tr("—–→←", "-")
    end
  end
end
