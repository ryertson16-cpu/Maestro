module Siage
  HOST = "professor.see.pb.gov.br"
  ORIGIN = "https://#{HOST}"

  PERIODS = [
    "1º Período",
    "2º Período",
    "3º Período",
    "4º Período"
  ].freeze

  CLASS_MODES = [
    "Aula",
    "Avaliação"
  ].freeze

  CLASS_TYPES = [
    "Avulso",
    "Plano de Ensino"
  ].freeze

  TIME_SLOTS = [
    "1º tempo",
    "2º tempo",
    "3º tempo",
    "4º tempo",
    "5º tempo",
    "6º tempo",
    "7º tempo",
    "8º tempo",
    "9º tempo"
  ].freeze

  PERIOD_WINDOWS = [
    [Date.new(2026, 2, 10), Date.new(2026, 4, 23), "1º Período"],
    [Date.new(2026, 4, 24), Date.new(2026, 7, 23), "2º Período"],
    [Date.new(2026, 7, 24), Date.new(2026, 10, 5), "3º Período"],
    [Date.new(2026, 10, 6), Date.new(2026, 12, 23), "4º Período"]
  ].freeze

  def self.period_label(bimester)
    PERIODS[bimester.to_i - 1]
  end

  def self.period_for_date(date)
    return if date.blank?

    day = date.to_date
    found = PERIOD_WINDOWS.find { |ini, fim, _label| day >= ini && day <= fim }
    found&.last
  end

  def self.bimester_for_date(date)
    label = period_for_date(date)
    return ((Date.current.month - 1) / 3) + 1 if label.blank?

    PERIODS.index(label).to_i + 1
  end

  def self.window_for_bimester(bimester)
    PERIOD_WINDOWS.find { |_ini, _fim, label| label == period_label(bimester) }
  end
end
