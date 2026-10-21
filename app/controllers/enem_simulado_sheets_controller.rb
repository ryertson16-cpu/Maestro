class EnemSimuladoSheetsController < ApplicationController
  before_action :authenticate_professor!
  before_action :set_sheet

  def show
    remember_current_classroom(@sheet.classroom || @simulado.classroom)
  end

  def update
    save_answers!
    if launching?
      return unless launch_submission!

      redirect_to enem_simulado_path(@simulado),
                  notice: "Nota #{format_note(@sheet.score)} lançada para #{@sheet.student.name} (#{@sheet.hits} acertos)."
    else
      redirect_to enem_simulado_sheet_path(@simulado, @sheet),
                  notice: "CN #{@sheet.cn_hits} · MT #{@sheet.mt_hits} · total #{@sheet.hits} → nota sugerida #{format_note(@sheet.score)}. Ainda não lançada."
    end
  end

  def suggest
    text = pdf_text
    if text.blank?
      redirect_to enem_simulado_sheet_path(@simulado, @sheet),
                  alert: "Não há texto neste PDF para a Lira ler. Preencha a grade ou use um gabarito digital."
      return
    end

    suggested = Enem::KeyParser.suggest_with_lira(text)
    if suggested.blank? || suggested.filled_count.zero?
      redirect_to enem_simulado_sheet_path(@simulado, @sheet),
                  alert: "A Lira não conseguiu sugerir o cartão. Confira na grade."
      return
    end

    @sheet.answers = suggested.letters
    @sheet.suggestion_source = "lira"
    @sheet.confirmed = false
    @sheet.recompute!
    @sheet.save!
    redirect_to enem_simulado_sheet_path(@simulado, @sheet),
                notice: "A Lira sugeriu #{suggested.filled_count} marcações. Confira e só então importe a nota."
  end

  def launch
    save_answers! if params[:answers].present?
    return unless launch_submission?

    redirect_to enem_simulado_path(@simulado),
                notice: "Nota #{format_note(@sheet.score)} lançada para #{@sheet.student.name} (#{@sheet.hits} acertos)."
  end

  def destroy
    name = @sheet.student.name
    @sheet.destroy!
    redirect_to enem_simulado_path(@simulado),
                notice: "#{name} saiu da lista de cartões. A nota já lançada na turma, se houver, permanece."
  end

  private

  def set_sheet
    @simulado = current_professor.enem_simulados.find(params[:enem_simulado_id])
    @sheet = @simulado.sheets.find(params[:id])
  end

  def launching?
    params[:commit].to_s.match?(/lançar|importar/i)
  end

  def save_answers!
    @sheet.answers = normalize_letters(params[:answers]) if params[:answers].present?
    @sheet.suggestion_source = @sheet.suggestion_source.presence || "manual"
    @sheet.recompute!
    @sheet.save!
  end

  def launch_submission!
    unless @simulado.key_confirmed?
      redirect_to enem_simulado_path(@simulado), alert: "Confirme o gabarito oficial antes de lançar notas."
      return false
    end

    status = Enem::GradeImporter.new(@simulado, professor: current_professor).import_sheet!(@sheet)
    unless status == :imported
      redirect_to enem_simulado_path(@simulado),
                  alert: status == :no_classroom ? "Este aluno está sem turma no caderno." : "Este cartão ainda não tem marcações."
      return false
    end

    true
  end

  def normalize_letters(raw)
    values = raw.respond_to?(:to_unsafe_h) ? raw.to_unsafe_h : raw.to_h
    (1..Enem::ScoreScale::QUESTION_COUNT).map { |index|
      value = values[index.to_s].to_s.upcase
      Question::LETTERS.include?(value) ? value : nil
    }
  end

  def pdf_text
    return "" unless @sheet.card_pdf.attached?

    @sheet.card_pdf.open { |file| Enem::KeyParser.from_pdf(file.path).text.to_s }
  end

  def format_note(value)
    return "—" if value.blank?

    format("%.1f", value).tr(".", ",")
  end
end
