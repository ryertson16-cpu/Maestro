module SchoolCalendar
  module Holidays
    module_function

    def for_year(year)
      easter = easter_date(year)
      [
        [Date.new(year, 1, 1), "Confraternização Universal"],
        [easter - 47, "Carnaval"],
        [easter - 46, "Carnaval"],
        [easter - 2, "Sexta-feira Santa"],
        [Date.new(year, 4, 21), "Tiradentes"],
        [Date.new(year, 5, 1), "Dia do Trabalho"],
        [easter + 60, "Corpus Christi"],
        [Date.new(year, 6, 24), "São João (PB)"],
        [Date.new(year, 8, 5), "Fundação da Paraíba"],
        [Date.new(year, 9, 7), "Independência do Brasil"],
        [Date.new(year, 10, 12), "Nossa Senhora Aparecida"],
        [Date.new(year, 11, 2), "Finados"],
        [Date.new(year, 11, 15), "Proclamação da República"],
        [Date.new(year, 11, 20), "Consciência Negra"],
        [Date.new(year, 12, 25), "Natal"]
      ]
    end

    def easter_date(year)
      a = year % 19
      b = year / 100
      c = year % 100
      d = b / 4
      e = b % 4
      f = (b + 8) / 25
      g = (b - f + 1) / 3
      h = (19 * a + b - d - g + 15) % 30
      i = c / 4
      k = c % 4
      l = (32 + 2 * e + 2 * i - h - k) % 7
      m = (a + 11 * h + 22 * l) / 451
      month = (h + l - 7 * m + 114) / 31
      day = ((h + l - 7 * m + 114) % 31) + 1
      Date.new(year, month, day)
    end
  end
end
