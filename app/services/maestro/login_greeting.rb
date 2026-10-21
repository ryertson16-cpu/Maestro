module Maestro
  class LoginGreeting
    def initialize(professor, now: Time.zone.now)
      @professor = professor
      @now = now
    end

    def toast
      {
        kind: "maestro",
        title: Lira::NAME,
        message: message,
        duration: 7000,
        wait_for_others: true
      }
    end

    def message
      name = @professor.greeting_name
      addressed = [ @professor.courtesy_role, name ].compact.join(" ")

      "#{hello}, #{addressed}. O que vamos fazer hoje?"
    end

    private

    def hello
      hour = @now.hour
      if hour < 12
        "Bom dia"
      elsif hour < 18
        "Boa tarde"
      else
        "Boa noite"
      end
    end
  end
end
