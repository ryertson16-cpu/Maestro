class RemindersController < ApplicationController
  before_action :authenticate_professor!

  def index
    reminders = current_professor.reminders.upcoming.limit(12)

    render json: {
      reminders: reminders.map { |reminder| Maestro::ReminderCard.new(reminder).as_json }
    }
  end

  def create
    result = Maestro::QuickAssistant.new(current_professor).call(
      params[:body],
      forced_reminder: ActiveModel::Type::Boolean.new.cast(params[:reminder])
    )

    status = result[:type] == "error" ? :unprocessable_entity : :ok
    render json: result, status: status
  end

  def destroy
    reminder = current_professor.reminders.kept.find(params[:id])
    reminder.undo!

    render json: { ok: true }
  rescue ActiveRecord::RecordNotFound
    render json: { ok: false }, status: :not_found
  end

  def due
    fired = Maestro::ReminderFiring.new(current_professor).call

    render json: {
      fired: fired.map { |reminder| Maestro::ReminderCard.new(reminder).as_json }
    }
  end
end
