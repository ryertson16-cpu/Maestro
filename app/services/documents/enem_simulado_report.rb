require "prawn/table"

module Documents
  class EnemSimuladoReport
    def initialize(professor:, simulado:, sheets:)
      @professor = professor
      @simulado = simulado
      @sheets = Array(sheets).sort_by { |sheet| [sheet.classroom_label.to_s, sheet.student.name.to_s] }
      @letterhead = Letterhead.new(professor)
    end

    def render
      pdf = Prawn::Document.new(
        page_size: "A4",
        page_layout: :portrait,
        margin: 36,
        info: {
          Title: "Relatório do simulado ENEM - #{@simulado.title}",
          Author: @professor.name.presence || "Maestro"
        }
      ) do |document|
        document.font_size 9
        @letterhead.draw(
          document,
          title: "RELATORIO DO SIMULADO ENEM",
          subtitle: ascii(subtitle),
          variant: :official
        )
        draw_context(document)
        draw_summary(document)
        draw_by_classroom(document)
        draw_results(document)
        draw_scale(document)
      end

      pdf.render
    ensure
      @letterhead.cleanup
    end

    private

    def subtitle
      [
        @simulado.title,
        @simulado.classroom.name,
        @simulado.applied_on&.strftime("%d/%m/%Y"),
        Activity::BIMESTERS[@simulado.bimester]
      ].compact.join(" · ")
    end

    def draw_context(pdf)
      pdf.fill_color "20263D"
      [
        ["Turma de referência", @simulado.classroom.name],
        ["Data", @simulado.applied_on&.strftime("%d/%m/%Y")],
        ["Bimestre", Activity::BIMESTERS[@simulado.bimester]],
        ["Itens", "90 (45 CN + 45 Matemática)"],
        ["Cartões", @sheets.size.to_s]
      ].each do |label, value|
        pdf.text ascii("#{label}: #{value}"), size: 10
      end
      pdf.move_down 10
      pdf.fill_color "707891"
      pdf.text "A nota 0-10 usa o total de acertos. CN e Matematica sao o detalhe da prova. Nao e o TRI do INEP.", size: 8
      pdf.move_down 12
    end

    def draw_summary(pdf)
      pdf.fill_color "1F4E79"
      pdf.text "Sintese", size: 11, style: :bold
      pdf.move_down 6
      pdf.fill_color "20263D"

      if @sheets.empty?
        pdf.text "Ainda nao ha cartoes neste simulado.", size: 10
        pdf.move_down 12
        return
      end

      imported = @sheets.count(&:confirmed?)
      rows = [
        ["Cartoes", "Importados", "Media CN", "Media Matematica", "Media total", "Media da nota"],
        [
          @sheets.size.to_s,
          imported.to_s,
          average(:cn_hits),
          average(:mt_hits),
          average(:hits),
          average_note
        ]
      ]

      pdf.table(rows, header: true, width: pdf.bounds.width) do |table|
        style_header(table)
        table.cells.align = :center
      end
      pdf.move_down 14
    end

    def draw_by_classroom(pdf)
      rooms = @sheets.group_by(&:classroom_label)
      return if rooms.size < 2

      pdf.fill_color "1F4E79"
      pdf.text "Por turma", size: 11, style: :bold
      pdf.move_down 6
      pdf.fill_color "20263D"

      rows = [["Turma", "Alunos", "Media CN", "Media Matematica", "Media total", "Media da nota"]]
      rooms.sort_by(&:first).each do |label, sheets|
        rows << [
          ascii(label),
          sheets.size.to_s,
          average(:cn_hits, sheets),
          average(:mt_hits, sheets),
          average(:hits, sheets),
          average_note(sheets)
        ]
      end

      pdf.table(rows, header: true, width: pdf.bounds.width) do |table|
        style_header(table)
        table.column(0).align = :left
        (1..5).each { |index| table.column(index).align = :center }
      end
      pdf.move_down 14
    end

    def draw_results(pdf)
      pdf.fill_color "1F4E79"
      pdf.text "Resultados", size: 11, style: :bold
      pdf.move_down 6
      pdf.fill_color "20263D"

      if @sheets.empty?
        pdf.text "Nenhum resultado para listar.", size: 10
        return
      end

      rows = [["N.", "Aluno", "Turma", "CN", "Mat.", "Total", "Nota", "Situacao"]]
      @sheets.each_with_index do |sheet, index|
        rows << [
          (index + 1).to_s,
          ascii(sheet.student.name),
          ascii(sheet.classroom_label),
          sheet.cn_hits.to_i.to_s,
          sheet.mt_hits.to_i.to_s,
          sheet.hits.to_i.to_s,
          format_note(sheet.score),
          sheet.confirmed? ? "Importada" : "Conferir"
        ]
      end

      pdf.table(rows, header: true, width: pdf.bounds.width) do |table|
        style_header(table)
        table.column(0).width = 28
        table.column(0).align = :center
        table.column(2).width = 52
        table.column(3).width = 32
        table.column(4).width = 36
        table.column(5).width = 38
        table.column(6).width = 36
        table.column(7).width = 58
        (3..6).each { |index| table.column(index).align = :center }
      end
      pdf.move_down 14
    end

    def draw_scale(pdf)
      pdf.fill_color "1F4E79"
      pdf.text "Escala de acertos para nota", size: 11, style: :bold
      pdf.move_down 6
      pdf.fill_color "20263D"

      rows = [["Acertos", "Nota", "Leitura"]]
      Enem::ScoreScale::BANDS.each do |band|
        rows << [
          "#{band[:hits].begin} a #{band[:hits].end}",
          "#{format_note(band[:notes].begin)} a #{format_note(band[:notes].end)}",
          ascii(band[:label])
        ]
      end

      pdf.table(rows, header: true, width: pdf.bounds.width) do |table|
        style_header(table)
        table.column(0).width = 80
        table.column(1).width = 90
      end
    end

    def style_header(table)
      table.row(0).font_style = :bold
      table.row(0).background_color = "E8EEF6"
      table.cells.size = 8
      table.cells.padding = [4, 5]
    end

    def average(field, sheets = @sheets)
      values = sheets.map { |sheet| sheet.public_send(field) }.compact
      return "-" if values.empty?

      format("%.1f", values.sum.to_f / values.size).tr(".", ",")
    end

    def average_note(sheets = @sheets)
      values = sheets.map(&:score).compact
      return "-" if values.empty?

      format_note(values.sum.to_f / values.size)
    end

    def format_note(value)
      return "-" if value.blank?

      format("%.1f", value).tr(".", ",")
    end

    def ascii(value)
      value.to_s
           .unicode_normalize(:nfkd)
           .gsub(/\p{M}/, "")
           .tr("—–→←", "-")
    end
  end
end
