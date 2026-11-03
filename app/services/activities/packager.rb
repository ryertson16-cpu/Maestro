require "json"

module Activities
  class Packager
    FORMAT = "maestro.activity.pack"
    VERSION = 1

    def initialize(activities:)
      @activities = Array(activities).filter_map { |activity|
        activity.adapted? ? activity.parent_activity : activity
      }.uniq
    end

    def as_json(*)
      {
        "format" => FORMAT,
        "version" => VERSION,
        "exported_at" => Time.current.iso8601,
        "activities" => @activities.map { |activity|
          Lessons::Packager.new(lessons: [ activity.lesson ]).packed_activity_entry(activity)
        }
      }
    end

    def to_pretty_json
      JSON.pretty_generate(as_json)
    end
  end
end
