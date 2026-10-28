require "csv"

module Siage
  class GradeSpreadsheet
    HEADERS = [
      "Aluno",
      "1ª unidade",
      "Rec 1",
      "2ª unidade",
      "Rec 2",
      "3ª unidade",
      "Rec 3",
      "Turma",
      "Bimestre",
      "Token Maestro",
      "Maestro"
    ].freeze

    def self.csv(payload)
      new(payload).csv
    end

    def initialize(payload)
      @payload = payload.is_a?(Hash) ? payload.with_indifferent_access : {}
    end

    def csv
      "\uFEFF" + CSV.generate(headers: true, col_sep: "\t") do |table|
        table << HEADERS
        Array(@payload[:grades]).each { |row| table << cells_for(row) }
      end
    end

    private

    def cells_for(row)
      row = row.with_indifferent_access
      units = Array(row[:units])
      [
        row[:name],
        score_cell(unit_value(units, 1, :score)),
        score_cell(unit_value(units, 1, :recovery)),
        score_cell(unit_value(units, 2, :score)),
        score_cell(unit_value(units, 2, :recovery)),
        score_cell(unit_value(units, 3, :score)),
        score_cell(unit_value(units, 3, :recovery)),
        @payload.dig(:classroom, :name) || @payload.dig(:classroom, "name"),
        @payload[:bimester],
        @payload[:token],
        @payload[:origin]
      ]
    end

    def unit_value(units, number, field)
      unit = units.find { |item| item.with_indifferent_access[:number].to_i == number } || {}
      unit.with_indifferent_access[field]
    end

    def score_cell(value)
      return "" unless NumericScore.recorded?(value)

      format("%.1f", value).tr(".", ",")
    end
  end
end
