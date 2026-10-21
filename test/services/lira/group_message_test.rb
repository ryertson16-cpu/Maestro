require "test_helper"

class Lira::GroupMessageTest < ActiveSupport::TestCase
  def load_fixtures(_config = ActiveRecord::Base)
    {}
  end

  setup do
    @professor = Professor.create!(
      name: "Ana Souza",
      preferred_name: "Ana",
      sex: "female",
      email: "lira-group-#{SecureRandom.hex(4)}@maestro.test",
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
    lesson = @professor.lessons.create!(
      classroom: @classroom,
      lesson_date: Date.yesterday,
      theme: "Relatório",
      siage_time_slot: "1",
      has_activity: true
    )
    @activity = lesson.create_activity!(
      title: "Lista de genética",
      activity_type: "Lista de exercícios",
      due_date: Date.yesterday,
      bimester: 1,
      weight: 1,
      maximum_score: 10
    )
    @pending = @professor.students.create!(name: "Carlos Mendes")
    @delivered = @professor.students.create!(name: "Maria Lima")
    [@pending, @delivered].each do |student|
      Enrollment.create!(
        professor: @professor,
        student: student,
        classroom: @classroom,
        enrolled_on: Date.current,
        status: "active"
      )
    end
    ActivitySubmission.create!(
      activity: @activity,
      student: @delivered,
      professor: @professor,
      submitted_on: Date.yesterday
    )
    @toolkit = Lira::Toolkit.new(@professor)
  end

  test "activity_delivery_status lists pending names and full counts" do
    payload = @toolkit.activity_delivery_status(
      classroom: "3ª O",
      activity: "genética",
      status: "não entregou"
    )

    assert_equal "Lista de genética", payload[:activity]
    assert_equal :not_delivered, payload[:status_filter]
    assert_equal 1, payload[:counts][:delivered]
    assert_equal 1, payload[:counts][:not_delivered]
    assert_equal ["Carlos Mendes"], payload[:students].map { |row| row[:name] }
  end

  test "local interpreter drafts a group alert with pending names" do
    reply = Lira::LocalInterpreter.new(@toolkit).reply(
      "Crie uma mensagem para o grupo da 3ª O alertando quem não entregou a \"Lista de genética\""
    )

    assert_match(/Tudo bem, professora Ana/, reply)
    assert_match(/Mensagem para colar no grupo/, reply)
    assert_includes reply, "Carlos Mendes"
    refute_includes reply, "Maria Lima"
    assert_match(/não envio no WhatsApp/i, reply)
  end

  test "delivery_text is the paste-ready WhatsApp body" do
    facts = @toolkit.activity_delivery_status(
      classroom: "3ª O",
      activity: "genética",
      status: "não entregou"
    )
    text = Lira::GroupMessage.delivery_text(facts)

    assert_includes text, "Carlos Mendes"
    refute_includes text, "Mensagem para colar no grupo"
  end

  test "drafts a generic group notice without inventing students" do
    reply = Lira::LocalInterpreter.new(@toolkit).reply(
      "mensagem para o grupo da 3ª O avisando da reunião de pais na sexta"
    )

    assert_match(/Mensagem para colar no grupo/, reply)
    assert_match(/reunião de pais/i, reply)
    refute_includes reply, "Carlos Mendes"
  end

  test "asks for the classroom when the group is not named" do
    reply = Lira::LocalInterpreter.new(@toolkit).reply(
      "mensagem para colar no grupo alertando quem não entregou"
    )

    assert_match(/Diga a turma do grupo/i, reply)
  end
end
