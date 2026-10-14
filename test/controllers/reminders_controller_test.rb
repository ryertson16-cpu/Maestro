require "test_helper"

class RemindersControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  def load_fixtures(_config = ActiveRecord::Base)
    {}
  end

  setup do
    @professor = Professor.create!(
      name: "Ryertson Silva",
      email: "lembrete-#{SecureRandom.hex(4)}@maestro.test",
      password: "password123",
      password_confirmation: "password123",
      preferred_name: "Ryertson",
      sex: "male"
    )
  end

  test "creates a reminder from a spoken sentence" do
    sign_in @professor

    travel_to Time.zone.parse("2026-10-09 08:15") do
      post reminders_path, params: {
        body: "Me lembra de buscar a encomenda amanhã às 17h"
      }, as: :json

      assert_response :success
      json = JSON.parse(response.body)
      assert_equal "reminder", json["type"]
      assert_equal "Buscar a encomenda", json["reminder"]["title"]
      assert_equal "17:00", json["reminder"]["time_label"]
      assert_equal 1, @professor.reminders.count
    end
  end

  test "undoes a reminder" do
    sign_in @professor
    reminder = @professor.reminders.create!(
      title: "Reunião",
      remind_at: 1.day.from_now
    )

    delete reminder_path(reminder), as: :json

    assert_response :success
    assert reminder.reload.undone?
  end
end
