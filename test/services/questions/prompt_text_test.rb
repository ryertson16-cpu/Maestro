require "test_helper"

class Questions::PromptTextTest < ActiveSupport::TestCase
  def load_fixtures(_config = ActiveRecord::Base)
    {}
  end

  test "keeps color size alignment table and a safe image" do
    html = <<~HTML
      <div style="text-align: center; position: absolute">
        <font color="#112233" size="5">Agua</font>
      </div>
      <table><tr><td>H</td><td>O</td></tr></table>
      <img src="data:image/jpeg;base64,AAAA" alt="">
      <img src="javascript:alert(1)">
      <script>alert(1)</script>
    HTML

    clean = Questions::PromptText.sanitized(html)

    assert_includes clean, "text-align: center"
    assert_not_includes clean, "position"
    assert_includes clean, "#112233"
    assert_includes clean, "size=\"5\""
    assert_includes clean, "<table>"
    assert_includes clean, "data:image/jpeg;base64,AAAA"
    assert_not_includes clean, "javascript:"
    assert_not_includes clean, "script"
  end

  test "draws the formatted prompt on a pdf" do
    pdf = Prawn::Document.new
    Questions::PromptText.draw(
      pdf,
      '<div style="text-align:center"><font color="#112233" size="5">Agua</font></div><table><tr><td>Hidrogenio</td></tr></table>',
      prefix: "1. ",
      size: 10
    )

    text = PDF::Reader.new(StringIO.new(pdf.render)).pages.map(&:text).join("\n")
    assert_includes text, "Agua"
    assert_includes text, "Hidrogenio"
  end
end
