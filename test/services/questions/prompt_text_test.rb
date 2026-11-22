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

  test "draws a quadro as text that stays readable in a narrow column" do
    pdf = Prawn::Document.new(page_size: [ 320, 500 ], margin: 28)
    Documents::PdfFont.apply(pdf)
    Questions::PromptText.draw(
      pdf,
      "<table><tr><th>Elemento</th><th>Massa</th><th>Carga</th></tr><tr><td>Hidrogenio</td><td>1</td><td>+1</td></tr></table>",
      prefix: "3. ",
      size: 9
    )
    page = PDF::Reader.new(StringIO.new(pdf.render)).pages.first
    text = page.text.gsub(/\s+/, " ")

    assert_includes text, "Elemento"
    assert_includes text, "Hidrogenio"
    assert_includes text, "+1"
    assert_empty page.xobjects
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

  test "returns the question sentence to the left after a right aligned citation" do
    pdf = Prawn::Document.new(page_size: "A4", margin: 36)
    Documents::PdfFont.apply(pdf)
    html = <<~HTML
      <div>O manual explica as cores da impressão.</div>
      <div style="text-align: right">ADOBE. Sobre cores. Disponível em: https://helpx.adobe.com/br/cores.html. Acesso em: 20 nov. 2026 (adaptado). Para o próximo cartaz, a medida que evita essa surpresa é</div>
    HTML
    Questions::PromptText.draw(pdf, html, prefix: "2. ", size: 10)
    page = PDF::Reader.new(StringIO.new(pdf.render)).pages.first
    runs = page.runs
    citation = runs.find { |run| run.text.include?("ADOBE") }
    question = runs.find { |run| run.text.include?("Para o próximo") }

    assert citation
    assert question
    assert_operator question.x, :<, citation.x
  end

  test "keeps the exam letter alignments from the editor" do
    pdf = Prawn::Document.new(page_size: "A4", margin: 36)
    Documents::PdfFont.apply(pdf)
    html = <<~HTML
      <div style="text-align: center">Escola de Magia</div>
      <div style="text-align: center">e Programação de Linguagem Web</div>
      <div>Queridos bruxos e bruxas da Escola de Magia e Programação de</div>
      <div>Linguagem Web, o ano foi intenso.</div>
      <div style="text-align: center"><i>Que a magia do código esteja pra sempre com vocês!</i></div>
      <div style="text-align: right"><b>Valter Machado</b></div>
      <div style="text-align: right"><i>Diretor da Escola de Magia e Programação de Linguagem Web</i></div>
    HTML
    Questions::PromptText.draw(pdf, html, prefix: "", size: 10)
    runs = PDF::Reader.new(StringIO.new(pdf.render)).pages.first.runs
    title = runs.find { |run| run.text.include?("Escola de Magia e Programação") }
    greeting = runs.find { |run| run.text.include?("Queridos bruxos") }
    closing = runs.find { |run| run.text.include?("magia do código") }
    name = runs.find { |run| run.text.include?("Valter Machado") }
    role = runs.find { |run| run.text.include?("Diretor da Escola") }

    assert title
    assert_includes greeting.text, "Linguagem Web,"
    assert closing
    assert name
    assert role
    assert_operator title.x, :>, greeting.x
    assert_operator name.x, :>, greeting.x
    refute_equal name.y, role.y
  end

  test "returns the question sentence to the left when the citation is italic" do
    pdf = Prawn::Document.new(page_size: "A4", margin: 36)
    Documents::PdfFont.apply(pdf)
    html = <<~HTML
      <div style="text-align: right"><i>ADOBE. Sobre cores. Disponível em: https://helpx.adobe.com/br/cores.html. Acesso em: 20 nov. 2026 (adaptado). Para o próximo cartaz, a medida que evita essa surpresa é</i></div>
    HTML
    Questions::PromptText.draw(pdf, html, prefix: "2. ", size: 10)
    runs = PDF::Reader.new(StringIO.new(pdf.render)).pages.first.runs
    citation = runs.find { |run| run.text.include?("ADOBE") }
    question = runs.find { |run| run.text.include?("Para o próximo") }

    assert citation
    assert question
    assert_operator question.x, :<, citation.x
  end

  test "keeps the editor alignment when the letter is wrapped in a table" do
    pdf = Prawn::Document.new(page_size: "A4", margin: 36)
    Documents::PdfFont.apply(pdf)
    html = <<~HTML
      <table><tr><td>
        <div style="text-align: center"><i>Escola de Magia<br>e Programação de Linguagem Web</i></div>
        <div>Queridos bruxos e bruxas da Escola de Magia e Programação de<br>Linguagem Web, o ano foi intenso.</div>
        <div style="text-align: right"><b>Valter Machado</b></div>
      </td></tr></table>
    HTML
    Questions::PromptText.draw(pdf, html, prefix: "", size: 10)
    runs = PDF::Reader.new(StringIO.new(pdf.render)).pages.first.runs
    title = runs.find { |run| run.text.include?("Escola de Magia e Programação") }
    greeting = runs.find { |run| run.text.include?("Queridos bruxos") }
    name = runs.find { |run| run.text.include?("Valter Machado") }

    assert title
    assert_includes greeting.text, "Linguagem Web,"
    assert name
    assert_operator title.x, :>, greeting.x
    assert_operator name.x, :>, greeting.x
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
