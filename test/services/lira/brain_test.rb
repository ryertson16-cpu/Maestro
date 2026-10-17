require "test_helper"

class Lira::BrainTest < ActiveSupport::TestCase
  def load_fixtures(_config = ActiveRecord::Base)
    {}
  end

  test "picks openai when only that key exists" do
    with_lira_env(
      "LIRA_BRAIN" => nil,
      "LIRA_OPENAI_API_KEY" => "sk-test",
      "OPENAI_API_KEY" => nil,
      "LIRA_GEMINI_API_KEY" => nil,
      "GEMINI_API_KEY" => nil
    ) do
      assert_equal :openai, Lira.brain_provider
      assert_match(/GPT/, Lira.brain_label)
    end
  end

  test "picks gemini when only that key exists" do
    with_lira_env(
      "LIRA_BRAIN" => nil,
      "LIRA_OPENAI_API_KEY" => nil,
      "OPENAI_API_KEY" => nil,
      "LIRA_GEMINI_API_KEY" => "gem-test",
      "GEMINI_API_KEY" => nil
    ) do
      assert_equal :gemini, Lira.brain_provider
      assert_match(/Gemini/, Lira.brain_label)
    end
  end

  test "explicit gemini does not fall back to openai" do
    with_lira_env(
      "LIRA_BRAIN" => "gemini",
      "LIRA_OPENAI_API_KEY" => "sk-test",
      "OPENAI_API_KEY" => nil,
      "LIRA_GEMINI_API_KEY" => nil,
      "GEMINI_API_KEY" => nil
    ) do
      assert_nil Lira.brain_provider
      refute Lira.llm_enabled?
      assert_match(/local/, Lira.brain_label)
    end
  end

  test "runner calls toolkit and returns the model text" do
    professor = Professor.create!(
      name: "Ana Souza",
      email: "brain-#{SecureRandom.hex(4)}@maestro.test",
      password: "password123",
      password_confirmation: "password123"
    )
    toolkit = Lira::Toolkit.new(professor)
    adapter = ScriptedAdapter.new(
      [
        {
          kind: :tools,
          calls: [{ id: "call-1", name: "list_classrooms", arguments: {} }]
        },
        { kind: :text, content: "Tudo bem, professora Ana. Seguem as turmas.\n\n📋 Nenhuma turma." }
      ]
    )

    answer = Lira::Brain.new(toolkit, adapter: adapter).reply("quais são minhas turmas?")

    assert_equal 1, adapter.tool_results.size
    assert_equal "list_classrooms", adapter.tool_results.first[:name]
    assert_includes answer, "Seguem as turmas"
  end

  class ScriptedAdapter
    attr_reader :tool_results

    def initialize(turns)
      @turns = turns
      @tool_results = []
    end

    def prepare(**)
    end

    def complete
      @turns.shift
    end

    def add_tool_result(**kwargs)
      @tool_results << kwargs
    end
  end

  def with_lira_env(values)
    previous = values.keys.index_with { |key| ENV[key] }
    values.each do |key, value|
      if value.nil?
        ENV.delete(key)
      else
        ENV[key] = value
      end
    end
    yield
  ensure
    previous.each do |key, value|
      if value.nil?
        ENV.delete(key)
      else
        ENV[key] = value
      end
    end
  end
end
