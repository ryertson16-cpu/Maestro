require "test_helper"

class ActivityTest < ActiveSupport::TestCase
  def load_fixtures(_config = ActiveRecord::Base)
    {}
  end

  setup do
    @professor = Professor.create!(
      name: "Ana Souza",
      preferred_name: "Ana",
      sex: "female",
      email: "activity-#{SecureRandom.hex(4)}@maestro.test",
      password: "password123",
      password_confirmation: "password123"
    )
    grade = @professor.grade_levels.create!(name: "3º ano")
    @classroom = @professor.classrooms.create!(
      name: "3ª O",
      school_year: 2026,
      grade_level: grade,
      active: true
    )
  end

  test "new activity lands in the SIAGE bimester of the creation date" do
    travel_to Date.new(2026, 10, 30) do
      activity = build_activity(due_date: Date.current)

      assert activity.save
      assert_equal 4, activity.bimester
    end
  end

  test "new activity in March lands in the first bimester even with a later due date" do
    travel_to Date.new(2026, 3, 12) do
      activity = build_activity(due_date: Date.new(2026, 11, 10))

      assert activity.save
      assert_equal 1, activity.bimester
    end
  end

  test "explicit bimester is kept when the activity is created with one" do
    travel_to Date.new(2026, 10, 30) do
      activity = build_activity(due_date: Date.new(2026, 10, 30), bimester: 2)

      assert activity.save
      assert_equal 2, activity.bimester
    end
  end

  test "changing the bimester later is not overwritten" do
    travel_to Date.new(2026, 10, 30) do
      activity = build_activity(due_date: Date.new(2026, 10, 30))
      activity.save!

      activity.update!(bimester: 1)
      assert_equal 1, activity.reload.bimester
    end
  end

  private

  def build_activity(due_date:, bimester: nil)
    lesson = @professor.lessons.create!(
      classroom: @classroom,
      lesson_date: Date.current,
      theme: "Genética",
      siage_time_slot: "1",
      has_activity: true
    )
    attrs = {
      title: "Lista de genética",
      activity_type: "Lista de exercícios",
      due_date: due_date,
      weight: 1,
      maximum_score: 10
    }
    attrs[:bimester] = bimester if bimester
    lesson.build_activity(attrs)
  end
end
