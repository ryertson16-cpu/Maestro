require "test_helper"

class Grades::BimesterScoreTest < ActiveSupport::TestCase
  def load_fixtures(_config = ActiveRecord::Base)
    {}
  end

  test "weighted average ignores complementary work and uses recovery only as a ceiling" do
    student = Object.new
    prova = stub_activity(weight: 2, score: 4, counts: true)
    lista = stub_activity(weight: 1, score: 8, counts: true)
    extra = stub_activity(weight: 1, score: 10, counts: false)
    recovery = Struct.new(:score).new(7)

    score = Grades::BimesterScore.new(
      student: student,
      activities: [prova, lista, extra],
      recovery: recovery
    )

    assert_equal 5.33, score.average
    assert_equal BigDecimal("7.0"), score.final_score
  end

  test "blank recovery keeps the weighted average as the final score" do
    student = Object.new
    activity = stub_activity(weight: 1, score: 8.13, counts: true)

    score = Grades::BimesterScore.new(student: student, activities: [activity])

    assert_equal 8.13, score.average
    assert_equal BigDecimal("8.1"), score.final_score
  end

  private

  def stub_activity(weight:, score:, counts:)
    submission = score.nil? ? nil : Struct.new(:score).new(score)
    source = Struct.new(:weight).new(weight)

    activity = Object.new
    activity.define_singleton_method(:counts_toward_average_for?) { |_student| counts }
    activity.define_singleton_method(:replacing_version_for) { |_student| nil }
    activity.define_singleton_method(:submission_for_average) { |_student| submission }
    activity.define_singleton_method(:weight) { source.weight }
    activity
  end
end
