require "test_helper"

class Lira::Brains::GeminiTest < ActiveSupport::TestCase
  def load_fixtures(_config = ActiveRecord::Base)
    {}
  end

  test "converts openai tool definitions to gemini function declarations" do
    openai_tools = [
      {
        type: "function",
        function: {
          name: "grades_report",
          description: "Notas de um aluno",
          parameters: {
            type: "object",
            properties: {
              classroom: { type: "string", description: "Turma" },
              bimester: { type: "integer", description: "1 a 4" }
            },
            required: %w[classroom]
          }
        }
      }
    ]

    tools = Lira::Brains::Gemini.new.gemini_tools(openai_tools)
    declaration = tools.dig(0, :functionDeclarations, 0)

    assert_equal "grades_report", declaration[:name]
    assert_equal "OBJECT", declaration[:parameters][:type]
    assert_equal "STRING", declaration[:parameters][:properties]["classroom"][:type]
    assert_equal "INTEGER", declaration[:parameters][:properties]["bimester"][:type]
    assert_equal %w[classroom], declaration[:parameters][:required]
  end
end
