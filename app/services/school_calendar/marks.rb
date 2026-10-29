module SchoolCalendar
  module Marks
    module_function

    ITEMS = [
      { value: "holiday", kind: "holiday", name: "Feriado", label: "Feriado" },
      { value: "saturday_school", kind: "saturday_school", name: "Sábado letivo", label: "Sábado letivo" },
      { value: "no_class", kind: "no_class", name: "Recesso", label: "Recesso" },
      { value: "planning", kind: "planning", name: "Planejamento", label: "Planejamento" },
      { value: "milestone", kind: "milestone", name: "Marco letivo", label: "Marco letivo" },
      { value: "letivo", kind: "letivo", name: "Dia letivo", label: "Dia letivo (SEE)" },
      { value: "F", kind: "holiday", name: "Feriado", label: "F — Feriado" },
      { value: "FM", kind: "no_class", name: "Férias e matrículas", label: "FM — Férias e matrículas" },
      { value: "FI", kind: "planning", name: "Formação inicial", label: "FI — Formação inicial" },
      { value: "JP", kind: "planning", name: "Jornada pedagógica", label: "JP — Jornada pedagógica" },
      { value: "RE", kind: "no_class", name: "Recesso escolar", label: "RE — Recesso escolar" },
      { value: "ODE", kind: "letivo", name: "Orçamento democrático escolar", label: "ODE — Orçamento democrático" },
      { value: "A", kind: "letivo", name: "Dia letivo", label: "A — Dia letivo", clear_weekday: true },
      { value: "IB", kind: "milestone", name: "Início do bimestre", label: "IB — Início do bimestre" },
      { value: "I1B", kind: "milestone", name: "Início do 1º bimestre", label: "I1B — Início do 1º bimestre" },
      { value: "I2B", kind: "milestone", name: "Início do 2º bimestre", label: "I2B — Início do 2º bimestre" },
      { value: "I3B", kind: "milestone", name: "Início do 3º bimestre", label: "I3B — Início do 3º bimestre" },
      { value: "I4B", kind: "milestone", name: "Início do 4º bimestre", label: "I4B — Início do 4º bimestre" },
      { value: "TB", kind: "milestone", name: "Término do bimestre", label: "TB — Término do bimestre" },
      { value: "T1B", kind: "milestone", name: "Término do 1º bimestre", label: "T1B — Término do 1º bimestre" },
      { value: "T2B", kind: "milestone", name: "Término do 2º bimestre", label: "T2B — Término do 2º bimestre" },
      { value: "T3B", kind: "milestone", name: "Término do 3º bimestre", label: "T3B — Término do 3º bimestre" },
      { value: "T4B", kind: "milestone", name: "Término do 4º bimestre", label: "T4B — Término do 4º bimestre" },
      { value: "RF", kind: "planning", name: "Recuperação final", label: "RF — Recuperação final" },
      { value: "CF", kind: "planning", name: "Conselho final", label: "CF — Conselho final" }
    ].freeze

    SKIP_CODES = %w[S D SD X].freeze

    def select_options
      ITEMS.map { |item| [item[:label], item[:value]] }
    end

    def resolve(value, date: nil, custom_name: nil)
      item = find(value)
      raise ArgumentError, "Escolha uma legenda do calendário." unless item

      if item[:clear_weekday]
        if date&.saturday?
          return { kind: "saturday_school", name: custom_name.presence || "Sábado letivo" }
        end

        return { clear: true }
      end

      { kind: item[:kind], name: custom_name.presence || item[:name] }
    end

    def from_see_code(code, date:, holiday_name: nil)
      normalized = code.to_s.upcase.gsub(/\s+/, "")
      return :skip if skip?(normalized)

      if normalized == "A"
        return { kind: "saturday_school", name: "Sábado letivo" } if date.saturday?

        return :plain
      end

      item = find(normalized)
      return :skip unless item

      name = if item[:kind] == "holiday"
               holiday_name.presence || item[:name]
             else
               item[:name]
             end

      { kind: item[:kind], name: name }
    end

    def find(value)
      key = value.to_s.strip
      ITEMS.find { |item| item[:value].casecmp?(key) }
    end

    def skip?(code)
      SKIP_CODES.include?(code) || code.match?(/\A-+\z/) || code.match?(/\A\d+\z/)
    end
  end
end
