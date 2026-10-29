module Documents
  class BimesterActionPlan
    def initialize(professor:, report:)
      @professor = professor
      @report = report
      @letterhead = Letterhead.new(professor)
    end

    def render
      pdf = Prawn::Document.new(
        page_size: "A4",
        page_layout: :portrait,
        margin: 36,
        info: {
          Title: "Plano de acao do bimestre",
          Author: @professor.name.presence || "Maestro"
        }
      ) do |document|
        document.font_size 10
        @letterhead.draw(
          document,
          title: "PLANO DE ACAO DO BIMESTRE",
          subtitle: "#{@report.grade_level.name} · #{@report.bimester}º bimestre"
        )
        draw_summary(document)
        draw_classrooms(document)
        draw_attention(document)
        draw_actions(document)
      end

      pdf.render
    ensure
      @letterhead.cleanup
    end

    private

    def draw_summary(pdf)
      pdf.fill_color "1F4E79"
      pdf.text "Sintese da serie", size: 12, style: :bold
      pdf.move_down 6
      pdf.fill_color "20263D"
      pdf.text "Media das turmas: #{score_or_dash(@report.series_average)}"
      pdf.text "Meta: #{score_or_dash(@report.target_average)}"
      pdf.text "Alunos abaixo do minimo: #{@report.below_total} de #{@report.student_count}"
      if @report.bimester_end
        pdf.text "Fim do bimestre: #{I18n.l(@report.bimester_end)} · #{@report.days_left} dia(s) restantes"
      end
      pdf.move_down 12
    end

    def draw_classrooms(pdf)
      pdf.fill_color "1F4E79"
      pdf.text "Turmas", size: 12, style: :bold
      pdf.move_down 6
      pdf.fill_color "20263D"

      @report.classroom_cards.each do |card|
        line = [
          card.classroom.name,
          "#{card.student_count} alunos",
          "media #{score_or_dash(card.average)}",
          ("#{signed(card.delta)} desde a ultima prova" if card.delta),
          "#{card.below_count} abaixo do minimo",
          ("mais fraco: #{card.weakest_label}" if card.weakest_label.present?)
        ].compact.join(" · ")
        pdf.text line, size: 9
        pdf.move_down 4
      end
      pdf.move_down 8
    end

    def draw_attention(pdf)
      pdf.fill_color "1F4E79"
      pdf.text "Onde agir primeiro", size: 12, style: :bold
      pdf.move_down 6
      pdf.fill_color "20263D"

      if @report.attention_points.empty?
        pdf.text "Ainda nao ha pontos de atencao com nota lancada."
      else
        @report.attention_points.each_with_index do |point, index|
          pdf.text "#{index + 1}. #{point.title}", style: :bold, size: 10
          pdf.text point.detail.to_s, size: 9
          pdf.move_down 4
        end
      end
      pdf.move_down 8
    end

    def draw_actions(pdf)
      pdf.fill_color "1F4E79"
      pdf.text "Plano de acao", size: 12, style: :bold
      pdf.move_down 6
      pdf.fill_color "20263D"

      actions = @report.actions.to_a
      if actions.empty?
        pdf.text "Nenhuma acao cadastrada neste bimestre."
        return
      end

      actions.each do |action|
        due = action.due_on.present? ? I18n.l(action.due_on) : "sem prazo"
        pdf.text "#{action.position}. #{action.title}", style: :bold, size: 10
        pdf.text [action.audience.presence, due].compact.join(" · "), size: 9
        pdf.move_down 4
      end
    end

    def score_or_dash(value)
      return "—" unless NumericScore.recorded?(value)

      format("%.1f", value.to_f).tr(".", ",")
    end

    def signed(value)
      number = format("%.1f", value.to_f).tr(".", ",")
      value.to_f.positive? ? "+#{number}" : number
    end
  end
end
