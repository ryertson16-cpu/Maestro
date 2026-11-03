module Siage
  class Handoff
    def self.payload(professor:, origin:, classroom: nil, mode: nil)
      new(professor: professor, origin: origin, classroom: classroom, mode: mode).payload
    end

    def initialize(professor:, origin:, classroom: nil, mode: nil)
      @professor = professor
      @origin = origin.to_s.presence
      @classroom = classroom
      @mode = mode.to_s
    end

    def payload
      return roster_payload if roster?

      dados = job
      notas = grade_payloads
      precisa = Array(dados["grupos"]).any? || notas.any?
      dados["status"] = precisa ? "aguardando-login" : "concluido"

      {
        "cpf" => professor.cpf.to_s,
        "senha" => professor.siage_password.to_s,
        "origin" => origin,
        "token" => dados["token"],
        "job" => dados,
        "grades" => notas
      }
    end

    private

    attr_reader :professor, :origin, :classroom, :mode

    def roster?
      mode == "roster"
    end

    def roster_payload
      token = Siage::ExtensionToken.generate(professor)
      dados = {
        "kind" => "roster",
        "status" => "aguardando-login",
        "teste" => false,
        "grupos" => [],
        "turmas" => [],
        "conhecidas" => professor.classrooms.order(:name).pluck(:name),
        "token" => token,
        "origin" => origin.to_s,
        "criado" => Time.current.to_i
      }

      {
        "cpf" => professor.cpf.to_s,
        "senha" => professor.siage_password.to_s,
        "origin" => origin,
        "token" => token,
        "mode" => "roster",
        "job" => dados,
        "grades" => []
      }
    end

    def open_lessons
      @open_lessons ||= Siage::Ledger.new(professor: professor, classroom: classroom).open_lessons
    end

    def job
      @job ||= Siage::SpreadsheetBuilder.new(
        professor: professor,
        classroom: classroom,
        lessons: open_lessons,
        origin: origin
      ).as_job
    end

    def grade_payloads
      rooms = classroom ? [classroom] : professor.classrooms.order(:name)

      rooms.flat_map do |room|
        (1..4).filter_map do |bimester|
          payload = Siage::PayloadBuilder.for_grades(
            professor: professor,
            classroom: room,
            bimester: bimester,
            origin: origin
          )
          next unless scored?(payload)

          payload
        end
      end
    end

    def scored?(payload)
      Array(payload[:grades] || payload["grades"]).any? do |row|
        Array(row[:units] || row["units"]).any? do |unit|
          NumericScore.recorded?(unit[:score] || unit["score"])
        end
      end
    end
  end
end
