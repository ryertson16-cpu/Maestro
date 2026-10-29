module Monitoring
  class SeriesReport
    ClassroomCard = Data.define(
      :classroom,
      :student_count,
      :average,
      :delta,
      :below_count,
      :weakest_label,
      :attention
    )
    AttentionPoint = Data.define(:kind, :title, :detail, :path)
    StudentNeed = Data.define(:student, :classroom, :average, :scored_count, :activity_count)

    attr_reader :grade_level, :bimester

    def initialize(professor:, grade_level:, bimester:)
      @professor = professor
      @grade_level = grade_level
      @bimester = bimester.to_i
    end

    def classroom_cards
      @classroom_cards ||= begin
        lagging_id = lagging_classroom&.id
        snapshots.map do |snapshot|
          ClassroomCard.new(
            classroom: snapshot.classroom,
            student_count: snapshot.students.size,
            average: snapshot.average,
            delta: snapshot.delta,
            below_count: snapshot.below_students.size,
            weakest_label: snapshot.weakest_activity_title,
            attention: snapshot.classroom.id == lagging_id
          )
        end
      end
    end

    def series_average
      values = snapshots.filter_map(&:average)
      return if values.empty?

      (values.sum / values.size).round(1)
    end

    def below_total
      snapshots.sum { |snapshot| snapshot.below_students.size }
    end

    def student_count
      snapshots.sum { |snapshot| snapshot.students.size }
    end

    def target_average
      setting&.target_average
    end

    def setting
      @setting ||= SeriesBimesterSetting.find_or_initialize_by(
        professor: @professor,
        grade_level: @grade_level,
        bimester: @bimester
      )
    end

    def attention_points
      points = []

      if lagging_classroom
        card = snapshots.find { |snapshot| snapshot.classroom.id == lagging_classroom.id }
        points << AttentionPoint.new(
          :classroom,
          "#{lagging_classroom.name} ficou para trás",
          [
            ("Média #{format_score(card.average)}" if card.average),
            ("#{card.below_students.size} aluno(s) abaixo de #{format_score(minimum_for(lagging_classroom))}" if card.below_students.any?),
            ("Mais fraco: #{card.weakest_activity_title}" if card.weakest_activity_title.present?)
          ].compact.join(" · "),
          "/monitoring?classroom_id=#{lagging_classroom.id}&grade_level_id=#{@grade_level.id}&bimester=#{@bimester}"
        )
      end

      if weakest_topic
        points << AttentionPoint.new(
          :topic,
          weakest_topic[:label],
          weakest_topic[:detail],
          weakest_topic[:path]
        )
      end

      if below_total.positive?
        points << AttentionPoint.new(
          :students,
          "#{below_total} aluno(s) abaixo da média mínima",
          "Só entram médias já lançadas neste bimestre.",
          "/monitoring?grade_level_id=#{@grade_level.id}&bimester=#{@bimester}"
        )
      end

      points.first(3)
    end

    def students_in_need
      snapshots
        .flat_map { |snapshot|
          snapshot.below_students.map do |row|
            StudentNeed.new(
              student: row[:student],
              classroom: snapshot.classroom,
              average: row[:average],
              scored_count: row[:scored_count],
              activity_count: snapshot.activities.size
            )
          end
        }
        .sort_by { |row| [ row.average, row.student.name ] }
        .first(5)
    end

    def actions
      @professor.bimester_actions.in_series(@grade_level, @bimester)
    end

    def window
      Siage.window_for_bimester(@bimester)
    end

    def bimester_end
      window&.[](1)
    end

    def days_left
      return if bimester_end.blank?

      [ (bimester_end - Date.current).to_i, 0 ].max
    end

    private

    Snapshot = Data.define(
      :classroom,
      :students,
      :activities,
      :averages,
      :below_students,
      :average,
      :delta,
      :weakest_activity_title,
      :item_miss
    )

    def snapshots
      @snapshots ||= classrooms.map { |classroom| snapshot_for(classroom) }
    end

    def classrooms
      @classrooms ||= @professor.classrooms
                                .where(grade_level: @grade_level)
                                .includes(:bimester_settings)
                                .order(:name)
                                .to_a
    end

    def snapshot_for(classroom)
      students = active_students(classroom)
      activities = Grades::BimesterScore.activities_for(classroom, @bimester)
                                         .includes(:activity_questions)
                                         .to_a
      recoveries = RecoveryGrade.where(
        professor: @professor,
        classroom: classroom,
        bimester: @bimester
      ).index_by(&:student_id)

      averages = {}
      scored_counts = {}
      students.each do |student|
        score = Grades::BimesterScore.new(
          student: student,
          activities: activities,
          recovery: recoveries[student.id]
        )
        final = score.final_score
        next unless NumericScore.recorded?(final)

        averages[student.id] = final.to_d
        scored_counts[student.id] = activities.count { |activity| activity.counts_toward_average_for?(student) && NumericScore.recorded?(activity.submission_for_average(student)&.score) }
      end

      minimum = minimum_for(classroom)
      below_students = students.filter_map do |student|
        average = averages[student.id]
        next unless average && average < minimum

        { student: student, average: average, scored_count: scored_counts[student.id].to_i }
      end

      values = averages.values
      class_average = values.any? ? (values.sum / values.size).round(1) : nil

      Snapshot.new(
        classroom: classroom,
        students: students,
        activities: activities,
        averages: averages,
        below_students: below_students,
        average: class_average,
        delta: delta_for(activities),
        weakest_activity_title: weakest_activity_title(activities),
        item_miss: item_miss_for(activities)
      )
    end

    def active_students(classroom)
      Enrollment
        .where(professor: @professor, classroom: classroom, status: "active")
        .includes(:student)
        .joins(:student)
        .order("students.name")
        .map(&:student)
    end

    def minimum_for(classroom)
      classroom.bimester_settings.find { |setting| setting.bimester == @bimester }&.minimum_score.presence || 6.to_d
    end

    def delta_for(activities)
      ordered = scored_checkpoints(activities)
      return if ordered.size < 2

      last = ordered[-1]
      previous = ordered[-2]
      return if last.nil? || previous.nil?

      (last - previous).round(1)
    end

    def scored_checkpoints(activities)
      ranked = activities.sort_by { |activity| [ activity.lesson&.lesson_date || Date.new(1900, 1, 1), activity.id ] }
      provas = ranked.select { |activity| prova?(activity) }
      series = provas.size >= 2 ? provas : ranked
      series.filter_map { |activity| activity_average(activity) }
    end

    def prova?(activity)
      activity.activity_type.to_s == "Prova" || activity.activity_questions.any?
    end

    def activity_average(activity)
      scores = activity.activity_submissions.filter_map { |row| row.score if NumericScore.recorded?(row.score) }
      return if scores.empty?

      (scores.sum { |score| score.to_d } / scores.size).round(1)
    end

    def weakest_activity_title(activities)
      ranked = activities.filter_map do |activity|
        average = activity_average(activity)
        next unless average

        [ average, activity.title ]
      end
      ranked.min_by(&:first)&.last
    end

    def item_miss_for(activities)
      tallies = Hash.new { |hash, key| hash[key] = { miss: 0, seen: 0, label: nil, activity: nil } }

      activities.each do |activity|
        items = activity.activity_questions.select(&:objective?)
        next if items.empty?

        activity.activity_submissions.each do |submission|
          answers = (submission.answers || {}).stringify_keys
          items.each do |item|
            given = answers[item.id.to_s].to_s.upcase
            next if given.blank?

            bucket = tallies[item.id]
            bucket[:seen] += 1
            bucket[:label] ||= item.prompt.to_s.truncate(80)
            bucket[:activity] ||= activity
            bucket[:miss] += 1 if given != item.correct_letter.to_s.upcase
          end
        end
      end

      worst = tallies.values.select { |row| row[:seen].positive? }.max_by { |row| row[:miss].to_f / row[:seen] }
      return if worst.blank? || worst[:miss].zero?

      rate = ((worst[:miss].to_f / worst[:seen]) * 100).round
      {
        label: worst[:label],
        detail: "#{rate}% de erros neste item · #{worst[:activity].title}",
        path: "/activities/#{worst[:activity].id}/assemble"
      }
    end

    def weakest_topic
      item = snapshots.filter_map(&:item_miss).max_by { |row|
        row[:detail].to_s[/\A(\d+)%/, 1].to_i
      }
      return item if item

      titles = snapshots.filter_map(&:weakest_activity_title)
      return if titles.empty?

      title = titles.tally.max_by { |_name, count| count }&.first
      activity = snapshots.flat_map(&:activities).find { |row| row.title == title }
      {
        label: title,
        detail: "Atividade com a menor média lançada neste bimestre.",
        path: activity ? "/activities/#{activity.id}/assemble" : "/monitoring"
      }
    end

    def lagging_classroom
      ranked = snapshots.select { |snapshot| snapshot.average.present? }
      return if ranked.empty?

      lowest = ranked.min_by(&:average)
      series = series_average
      minimum = minimum_for(lowest.classroom)
      behind = series && lowest.average < series
      below_min = lowest.average < minimum
      return unless behind || below_min
      return if ranked.size == 1 && !below_min

      lowest.classroom
    end

    def format_score(value)
      format("%.1f", value.to_f).tr(".", ",")
    end
  end
end
