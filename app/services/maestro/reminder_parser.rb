module Maestro
  class ReminderParser
    WEEKDAYS = {
      "segunda" => 1,
      "terca" => 2,
      "quarta" => 3,
      "quinta" => 4,
      "sexta" => 5,
      "sabado" => 6,
      "domingo" => 7
    }.freeze

    Result = Data.define(:title, :remind_at, :error)

    def initialize(text, now: Time.zone.now, forced: false)
      @raw = text.to_s.strip
      @now = now
      @forced = forced
    end

    def reminder_intent?
      @forced || normalized.match?(
        /\b(me lembra|lembr(e|ar|a)|lembrete|me avisa|me aviso)\b/
      )
    end

    def parse
      return Result.new(nil, nil, nil) unless reminder_intent?

      time = extract_time
      date = extract_date
      remind_at = combine(date, time)

      if remind_at.blank?
        return Result.new(nil, nil, "Diga o dia e o horário, por exemplo: me lembra da reunião amanhã às 19h.")
      end

      if remind_at <= @now
        return Result.new(nil, nil, "Esse horário já passou. Escolha outro.")
      end

      Result.new(extract_title, remind_at, nil)
    end

    private

    def normalized
      @normalized ||= Lessons::NameMatcher.normalize(@raw)
    end

    def extract_time
      if (match = @raw.match(/(?:às|as)\s*(\d{1,2})(?:[:h](\d{2}))?h?/i))
        return build_time(match[1], match[2])
      end

      if (match = @raw.match(/\b(\d{1,2}):(\d{2})\b/))
        return build_time(match[1], match[2])
      end

      if (match = @raw.match(/\b(\d{1,2})h(\d{2})?\b/i))
        return build_time(match[1], match[2])
      end

      nil
    end

    def build_time(hour, minute)
      h = hour.to_i
      m = minute.to_i
      return if h > 23 || m > 59

      [h, m]
    end

    def extract_date
      if normalized.match?(/\bhoje\b/)
        return @now.to_date
      end

      if normalized.match?(/\bdepois de amanha\b/)
        return @now.to_date + 2
      end

      if normalized.match?(/\bamanha\b/)
        return @now.to_date + 1
      end

      WEEKDAYS.each do |name, cwday|
        next unless normalized.match?(/\b#{name}(\s+feira)?\b/)

        return next_weekday(cwday)
      end

      nil
    end

    def next_weekday(cwday)
      date = @now.to_date
      delta = (cwday - date.cwday) % 7
      delta = 7 if delta.zero? && extract_time && past_today?(extract_time)
      delta = 7 if delta.zero? && extract_time.nil?
      date + delta
    end

    def past_today?(time_parts)
      hour, minute = time_parts
      @now.change(hour: hour, min: minute, sec: 0) <= @now
    end

    def combine(date, time_parts)
      hour, minute = time_parts || [8, 0]

      if date.blank?
        candidate = @now.change(hour: hour, min: minute, sec: 0)
        return candidate > @now ? candidate : candidate + 1.day
      end

      Time.zone.local(date.year, date.month, date.day, hour, minute, 0)
    end

    def extract_title
      text = @raw.dup
      text.sub!(/\A(me\s+lembra(?:r)?|lembr(?:e|ar|a)|lembrete|me\s+avisa)\s*(de|da|do|que)?\s*/i, "")
      text.gsub!(/(?:às|as)\s*\d{1,2}(?:[:h]\d{2})?h?/i, "")
      text.gsub!(/\b\d{1,2}:\d{2}\b/, "")
      text.gsub!(/\b\d{1,2}h\d{0,2}\b/i, "")
      text.gsub!(/\b(hoje|amanh[ãa]|depois de amanh[ãa])\b/i, "")
      text.gsub!(/\b(na|no)?\s*(segunda|ter[cç]a|quarta|quinta|sexta|s[áa]bado|domingo)(-feira)?\b/i, "")
      text.gsub!(/\b(de|da|do|para|pra|que)\s*\z/i, "")
      text.gsub!(/\A(de|da|do|que)\s+/i, "")
      text.gsub!(/\s+/, " ")
      title = text.strip
      title = "Lembrete" if title.blank?
      title[0] = title[0].upcase
      title.truncate(160)
    end
  end
end
