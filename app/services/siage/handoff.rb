module Siage
  class Handoff
    def self.payload(professor:, origin:, classroom: nil)
      new(professor: professor, origin: origin, classroom: classroom).payload
    end

    def initialize(professor:, origin:, classroom: nil)
      @professor = professor
      @origin = origin.to_s.presence
      @classroom = classroom
    end

    def payload
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

    attr_reader :professor, :origin, :classroom

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
      bimester = Siage.bimester_for_date(Date.current)
      rooms = classroom ? [classroom] : professor.classrooms.order(:name)

      rooms.filter_map do |room|
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

    def scored?(payload)
      Array(payload[:grades] || payload["grades"]).any? do |row|
        Array(row[:units] || row["units"]).any? do |unit|
          NumericScore.recorded?(unit[:score] || unit["score"])
        end
      end
    end
  end
end
