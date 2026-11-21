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

  test "keeps a sentence on the same line when the editor split it" do
    pdf = Prawn::Document.new(page_size: "A4", margin: 36)
    Questions::PromptText.draw(
      pdf,
      '<font size="4">Para a</font> campanha de doação<div>de sangue da escola</div>',
      prefix: "2. ",
      size: 10
    )
    text = PDF::Reader.new(StringIO.new(pdf.render)).pages.map(&:text).join(" ")
    assert_includes text.gsub(/\s+/, " "), "Para a campanha de doação de sangue da escola"
  end

  test "keeps the list marker on the same line as the item" do
    pdf = Prawn::Document.new
    Questions::PromptText.draw(
      pdf,
      "<ul><li>\nLeia o texto inteiro antes de responder</li></ul>",
      prefix: "",
      size: 10
    )
    text = PDF::Reader.new(StringIO.new(pdf.render)).pages.map(&:text).join(" ")
    assert_match(/•\s*Leia o texto inteiro/, text.gsub(/\s+/, " "))
  end

  test "draws an image nested in the prompt" do
    png = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
    pdf = Prawn::Document.new
    Questions::PromptText.draw(
      pdf,
      %(<div>Antes da figura</div><div><img src="#{png}" alt="IBM"></div><div style="text-align: right">IBM. The IBM logo.</div>),
      prefix: "9. ",
      size: 10
    )
    reader = PDF::Reader.new(StringIO.new(pdf.render))
    text = reader.pages.map(&:text).join(" ")
    assert_includes text.gsub(/\s+/, " "), "Antes da figura"
    assert_includes text, "IBM. The IBM logo."
    assert reader.pages.any? { |page| page.xobjects.any? }
  end
end
