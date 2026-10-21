require "test_helper"

class Lira::ScopeTest < ActiveSupport::TestCase
  setup do
    @professor = Professor.new(name: "Ryertson", sex: "male")
    @professora = Professor.new(name: "Ana Souza", preferred_name: "Ana", sex: "female")
  end

  test "opening names the professor and follows the question topic" do
    attendance = Lira::Scope.opening_line(professor: @professor, topic: :attendance)
    grades = Lira::Scope.opening_line(professor: @professora, topic: :grades)

    assert_equal "Tudo bem, professor Ryertson. Segue a frequência.", attendance
    assert_equal "Tudo bem, professora Ana. Seguem as notas.", grades
  end

  test "with_opening does not duplicate the greeting" do
    first = Lira::Scope.with_opening("✅ Maria: 90%", professor: @professor, topic: :attendance)
    second = Lira::Scope.with_opening(first, professor: @professor, topic: :attendance)

    assert_equal first, second
    assert_match(/\ATudo bem, professor Ryertson\. Segue a frequência\./, first)
  end

  test "system prompt keeps caderno rules and emoji labels" do
    prompt = Lira::Scope.system_prompt(professor: @professor)

    assert_match(/atraso não é falta/i, prompt)
    assert_match(/não invente/i, prompt)
    assert_match(/REC GLOBAL/, prompt)
    assert_match(/SIAGE/, prompt)
    assert_includes prompt, Lira::Scope.icon(:late)
    assert_includes prompt, Lira::Scope.icon(:siage)
    assert_includes prompt, Lira::Scope.icon(:project)
    assert_match(/Mensagem para colar no grupo/, prompt)
    assert_match(/Nunca envie a mensagem/i, prompt)
  end

  test "help and topic cover group WhatsApp drafts" do
    assert_match(/mensagem para o grupo/i, Lira::Scope.help_text)
    assert_equal :whatsapp, Lira::Scope.topic_for("mensagem para colar no grupo da 3ª O")
  end

  test "attendance format marks late as distinct from absence" do
    text = Lira::Scope.format_result(
      {
        month: "2026-10",
        classroom: "2ª F",
        students: [
          { name: "Maria", percentage: 90, present: 8, absent: 1, late: 2 }
        ]
      },
      professor: @professor,
      topic: :attendance
    )

    assert_match(/Tudo bem, professor Ryertson/, text)

    assert_includes text, Lira::Scope.icon(:attendance)
    assert_includes text, Lira::Scope.icon(:late)
    assert_includes text, Lira::Scope.icon(:absent)
    assert_match(/atraso não é falta/i, text)
    assert_includes text, "Maria"
  end

  test "projects format keeps them out of SIAGE" do
    text = Lira::Scope.format_result(
      [
        {
          title: "Horta",
          kind_label: "Turma",
          status: "em andamento",
          progress: 40,
          classrooms: ["2ª F"],
          overdue: []
        }
      ]
    )

    assert_includes text, Lira::Scope.icon(:project)
    assert_match(/não entram no SIAGE/i, text)
    assert_includes text, "Horta"
  end
end
