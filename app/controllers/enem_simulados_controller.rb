class EnemSimuladosController < ApplicationController
  before_action :authenticate_professor!
  before_action :set_simulado, only: %i[show update_key create_sheet import_sheets report]

  def index
    @classroom = resolve_classroom(fallback: true)
    scope = current_professor.enem_simulados.includes(:classroom, :activity).order(applied_on: :desc, id: :desc)
    scope = scope.where(classroom: @classroom) if @classroom
    @simulados = scope
  end

  def new
    @classrooms = current_professor.classrooms.order(:name)
    @classroom = resolve_classroom(fallback: true)
    @title = "Simulado ENEM — CN e Matemática"
    @applied_on = Date.current
    @bimester = Siage.bimester_for_date(@applied_on)
  end

  def create
    classroom = current_professor.classrooms.find(params[:classroom_id])
    upload = params[:official_pdf]
    unless upload.respond_to?(:tempfile)
      return fail_new("Envie o PDF do gabarito oficial.")
    end
    if upload.size > 20.megabytes
      return fail_new("O PDF do gabarito deve ter no máximo 20 MB.")
    end

    parsed = Enem::KeyParser.from_pdf(upload.tempfile.path)
    if parsed.filled_count < 80 && parsed.text.present? && Lira.brain_provider.present?
      suggested = Enem::KeyParser.suggest_with_lira(parsed.text)
      parsed = suggested if suggested&.filled_count.to_i > parsed.filled_count
    end

    applied_on = Date.parse(params[:applied_on].to_s)
    simulado = current_professor.enem_simulados.new(
      classroom: classroom,
      title: params[:title].presence || "Simulado ENEM — CN e Matemática",
      applied_on: applied_on,
      bimester: params[:bimester].presence || Siage.bimester_for_date(applied_on),
      question_count: Enem::ScoreScale::QUESTION_COUNT,
      official_key: parsed.letters,
      key_source: parsed.source,
      key_confirmed: false
    )
    simulado.official_pdf.attach(upload)

    if simulado.save
      remember_current_classroom(classroom)
      redirect_to enem_simulado_path(simulado),
                  notice: key_notice(parsed)
    else
      fail_new(simulado.errors.full_messages.to_sentence)
    end
  rescue Date::Error
    fail_new("Informe a data do simulado.")
  rescue ActiveRecord::RecordNotFound
    fail_new("Escolha uma turma do caderno.")
  end

  def show
    remember_current_classroom(@simulado.classroom)
    @sheets = @simulado.sheets.includes(:student, :classroom).sort_by { |sheet| sheet.student.name }
    @sheets.each do |sheet|
      sheet.recompute!
      sheet.save if sheet.changed?
    end
    @students = @simulado.students_in_caderno
    @student_options = @students.map { |student|
      room = Enem::ClassroomResolver.new(student: student, preferred: @simulado.classroom).classroom
      ["#{student.name} — #{room&.name || 'sem turma'}", student.id]
    }
    @pending_cards = @simulado.pending_cards.order(id: :desc)
  end

  def update_key
    letters = normalize_letters(params[:key])
    unless letters.all? { |letter| Question::LETTERS.include?(letter) }
      redirect_to enem_simulado_path(@simulado),
                  alert: "Confira as 90 letras (A–E) antes de confirmar o gabarito."
      return
    end

    @simulado.update!(official_key: letters, key_confirmed: true, key_source: @simulado.key_source.presence || "manual")
    Enem::ActivityBuilder.new(@simulado).ensure_activity!
    redirect_to enem_simulado_path(@simulado),
                notice: "Gabarito confirmado. Suba os cartões — a Lira só sugere. A nota só entra na importação."
  end

  def create_sheet
    unless @simulado.key_confirmed?
      redirect_to enem_simulado_path(@simulado), alert: "Confirme o gabarito oficial antes de ler os cartões."
      return
    end

    result = Enem::CardIntake.new(@simulado).call(
      uploads: Enem::CardIntake.uploads_from(params),
      student_id: params[:student_id]
    )
    redirect_to enem_simulado_path(@simulado),
                notice: sheet_notice(result).presence,
                alert: sheet_alert(result).presence
  end

  def report
    sheets = @simulado.sheets.includes(:student, :classroom)
    pdf = Documents::EnemSimuladoReport.new(
      professor: current_professor,
      simulado: @simulado,
      sheets: sheets
    ).render

    send_data pdf,
              filename: "relatorio-simulado-enem-#{@simulado.title.to_s.parameterize}-#{@simulado.applied_on}.pdf",
              type: "application/pdf",
              disposition: "attachment"
  end

  def import_sheets
    unless @simulado.key_confirmed?
      redirect_to enem_simulado_path(@simulado), alert: "Confirme o gabarito oficial antes de importar."
      return
    end

    counts = Enem::GradeImporter.new(@simulado, professor: current_professor).import_all!
    redirect_to enem_simulado_path(@simulado), notice: import_notice(counts)
  end

  private

  def set_simulado
    @simulado = current_professor.enem_simulados.find(params[:id])
  end

  def fail_new(message)
    @classrooms = current_professor.classrooms.order(:name)
    @classroom = current_professor.classrooms.find_by(id: params[:classroom_id]) || resolve_classroom(fallback: true)
    @title = params[:title]
    @applied_on = params[:applied_on]
    @bimester = params[:bimester]
    flash.now[:alert] = message
    render :new, status: :unprocessable_entity
  end

  def normalize_letters(raw)
    values = if raw.respond_to?(:to_unsafe_h)
      raw.to_unsafe_h
    else
      raw.to_h
    end
    (1..Enem::ScoreScale::QUESTION_COUNT).map { |index|
      value = values[index.to_s].to_s.upcase
      Question::LETTERS.include?(value) ? value : nil
    }
  end

  def key_notice(parsed)
    if parsed.filled_count >= 80
      "Li #{parsed.filled_count} respostas no PDF. Confira o gabarito antes de continuar."
    else
      "Não consegui ler o gabarito automaticamente. Preencha as 90 letras e confirme."
    end
  end

  def sheet_notice(result)
    parts = []
    received = result.received.to_i
    parts << "Recebi #{received} #{received == 1 ? 'PDF' : 'PDFs'}." if received.positive?
    if result.saved.any?
      parts << "#{result.saved.size} #{result.saved.size == 1 ? 'já ligado a um aluno' : 'já ligados a alunos'}."
    end
    if result.parked.any?
      parts << "#{result.parked.size} na lista para ligar. A Lira continua lendo os nomes em segundo plano — atualize a página se ainda faltar algum."
    end
    parts.join(" ")
  end

  def sheet_alert(result)
    result.errors.join(" ")
  end

  def import_notice(counts)
    imported = "#{counts[:imported]} #{counts[:imported] == 1 ? 'nota importada' : 'notas importadas'}"
    extras = []
    extras << "#{counts[:empty]} sem marcação" if counts[:empty].positive?
    extras << "#{counts[:no_classroom]} sem turma" if counts[:no_classroom].positive?
    "#{([imported] + extras).to_sentence} na tabela de atividades da turma de cada aluno."
  end
end
