module Enem
  module ScoreScale
    module_function

    QUESTION_COUNT = 90
    CN_COUNT = 45
    MT_COUNT = 45
    CN_RANGE = 0...CN_COUNT
    MT_RANGE = CN_COUNT...QUESTION_COUNT

    BANDS = [
      { hits: 0..8, notes: 0.0..0.9, label: "Muito abaixo do acaso" },
      { hits: 9..17, notes: 1.0..1.9, label: "Abaixo do acaso" },
      { hits: 18..26, notes: 2.0..2.9, label: "Na faixa do chute (~20%)" },
      { hits: 27..35, notes: 3.0..3.9, label: "Início de domínio" },
      { hits: 36..44, notes: 4.0..4.9, label: "Ainda abaixo da média" },
      { hits: 45..53, notes: 6.0..6.9, label: "Metade dos itens — média 6,0" },
      { hits: 54..62, notes: 7.0..7.9, label: "Acima da média" },
      { hits: 63..71, notes: 8.0..8.4, label: "Bom desempenho" },
      { hits: 72..80, notes: 8.5..9.4, label: "Ótimo desempenho" },
      { hits: 81..90, notes: 9.5..10.0, label: "Excelente" }
    ].freeze

    def note_for(hits)
      hits = hits.to_i.clamp(0, QUESTION_COUNT)
      band = BANDS.find { |item| item[:hits].cover?(hits) }
      range_h = band[:hits]
      range_n = band[:notes]
      span = range_h.end - range_h.begin
      ratio = span.zero? ? 0.to_d : (hits - range_h.begin).to_d / span
      raw = range_n.begin.to_d + (ratio * (range_n.end.to_d - range_n.begin.to_d))
      NumericScore.round_final(raw)
    end

    def band_for(hits)
      hits = hits.to_i.clamp(0, QUESTION_COUNT)
      BANDS.find { |item| item[:hits].cover?(hits) }
    end
  end
end
