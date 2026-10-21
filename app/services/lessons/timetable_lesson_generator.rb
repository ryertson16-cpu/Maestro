module Lessons
  class TimetableLessonGenerator
    WEEKDAYS = {
      0 => "domingo",
      1 => "segunda",
      2 => "terca",
      3 => "quarta",
      4 => "quinta",
      5 => "sexta",
      6 => "sabado"
    }.freeze

    def initialize(professor:, classroom:, lesson_date:, upload:, course: nil)
      @professor = professor
      @classroom = classroom
      @lesson_date = lesson_date
      @upload = upload
      @selected_course = course
    end

    def call
      error = validate_upload
      return { ok: false, error: error } if error

      text = extract_text
      return { ok: false, error: "Não consegui ler o texto deste PDF." } if text.blank?

      unless classroom_mentioned?(text)
        return {
          ok: false,
          error: "A turma #{@classroom.name} não aparece neste horário. Confira se o PDF é o dia certo."
        }
      end

      catalog = course_catalog
      io = @upload.tempfile
      io.rewind if io.respond_to?(:rewind)
      slots = Lessons::TimetableParser.new(
        text: text,
        professor: @professor,
        classroom: @classroom,
        courses: catalog,
        pdf: io
      ).slots

      if @selected_course
        preferred = slots.select { |slot| discipline_match?(slot[:subject], @selected_course.name) }
        slots = preferred if preferred.any?
      end

      if slots.empty?
        first = @professor.name.to_s.split.first
        if Lessons::NameMatcher.professor_in_text?(text, @professor.name)
          return {
            ok: false,
            error: "Achei o nome #{first} no PDF, mas não consegui ligar a disciplina desta turma. Confira se a turma e a disciplina estão cadastradas no Maestro."
          }
        end

        return {
          ok: false,
          error: "Não encontrei #{first} neste horário para gerar a aula."
        }
      end

      course = pick_course(slots, catalog) || @selected_course
      if course
        matched = slots.select { |slot| discipline_match?(slot[:subject], course.name) }
        slots = matched if matched.any?
      else
        named = slots.select { |slot| catalog_subject?(slot[:subject], catalog) }
        slots = named if named.any?
        course = pick_course(slots, catalog)
      end

      payload_for(course, slots, text)
    end

    private

    def validate_upload
      return "Anexe o PDF do horário da escola." if @upload.blank?

      name = @upload.original_filename.to_s
      type = @upload.content_type.to_s
      unless name.match?(/\.pdf\z/i) || type.include?("pdf")
        return "O arquivo precisa ser um PDF."
      end

      return "O PDF é grande demais (máximo 8 MB)." if @upload.size.to_i > 8.megabytes

      nil
    end

    def extract_text
      io = @upload.tempfile
      io.rewind
      pages = PDF::Reader.new(io).pages.map { |page| page.text.to_s }
      pages.join("\n")
    rescue PDF::Reader::MalformedPDFError, PDF::Reader::UnsupportedFeatureError
      ""
    end

    def classroom_mentioned?(text)
      Lessons::NameMatcher.classroom_in_text?(text, @classroom.name)
    end

    def course_catalog
      listed = @professor.courses.to_a
      listed.concat(Array(@classroom.school_course&.courses))
      listed << @classroom.course if @classroom.course
      listed << @selected_course if @selected_course
      listed.compact.uniq(&:id)
    end

    def catalog_subject?(text, catalog)
      catalog.any? { |course| discipline_match?(text, course.name) }
    end

    def pick_course(slots, catalog)
      if @selected_course && slots.any? { |slot| discipline_match?(slot[:subject], @selected_course.name) }
        return @selected_course
      end

      slots.each do |slot|
        match = catalog.find { |course| discipline_match?(slot[:subject], course.name) }
        return match if match
      end

      @selected_course
    end

    def discipline_match?(left, right)
      Lessons::NameMatcher.discipline_match?(left, right)
    end

    def same_name?(left, right)
      Lessons::NameMatcher.similar?(left, right)
    end

    def payload_for(course, slots, text)
      tempos = slots.map { |slot| slot[:period] }.uniq.sort
      first_slot = tempos.first
      subject_name = course&.name.presence || slots.map { |slot| slot[:subject] }.compact.first || "Componente curricular"
      weekday_pdf = Lessons::NameMatcher.weekday_in_text(
        text,
        filename: @upload.original_filename
      )
      weekday_date = WEEKDAYS[@lesson_date.wday]
      warning = nil
      if weekday_pdf && weekday_date && !weekday_pdf.start_with?(weekday_date[0, 4])
        warning = "O PDF parece ser de #{weekday_pdf}-feira, e a data da aula é #{weekday_date}-feira."
      end
      if course.blank?
        extra = "Selecione a disciplina no formulário para o SIAGE exportar o componente certo."
        warning = [warning, extra].compact.join(" ")
      end

      {
        ok: true,
        warning: warning,
        message: "Encontrei #{tempos.size} tempo(s) de #{subject_name} para #{@classroom.name}.",
        classroom_id: @classroom.id,
        course_id: course&.id,
        course_name: subject_name,
        theme: "Aula de #{subject_name}",
        objective: "Compreender e aplicar os conteúdos de #{subject_name} com a turma #{@classroom.name}, nos tempos previstos no horário escolar.",
        content: content_for(subject_name, slots),
        methodology: "Exposição dialogada, registro no quadro e resolução de situações-problema, conforme o plano da disciplina.",
        siage_period: period_for_date,
        siage_class_mode: "Aula",
        siage_class_type: "Avulso",
        siage_time_slot: "#{first_slot}º tempo",
        weekday: @lesson_date.cwday,
        slots: slots.map { |slot|
          {
            period: slot[:period],
            time_slot: "#{slot[:period]}º tempo",
            subject: slot[:subject]
          }
        }
      }
    end

    def content_for(subject_name, slots)
      lines = slots.map do |slot|
        time = [slot[:start_time], slot[:end_time]].compact.join(" – ")
        "#{slot[:period]}º tempo#{time.present? ? " (#{time})" : ""} — #{slot[:subject]}"
      end
      "Conteúdos de #{subject_name} de acordo com o horário escolar.\n#{lines.join("\n")}"
    end

    def period_for_date
      Siage.period_for_date(@lesson_date)
    end
  end
end
