require "test_helper"

class Activities::OnlineFormParserTest < ActiveSupport::TestCase
  def load_fixtures(_config = ActiveRecord::Base)
    {}
  end

  test "reads google forms csv headers and latest attempt by student" do
    path = Rails.root.join("tmp/online-form-test.csv")
    File.write(
      path,
      <<~CSV
        Carimbo de data/hora,Pontuação,Nome do estudante,Turma,1) Questão um,2) Questão dois
        08/10/2026 22:29:39,18.0,Maria Silva,3ª Série M,Alceno,Éter e Fenol
        09/10/2026 10:00:00,20.0,Maria Silva,3ª Série M,Alceno,Cetona
        09/10/2026 11:00:00,16.0,João Nunes,3ª Série N,Ácido carboxílico,Éter e Fenol
      CSV
    )

    rows = Activities::OnlineFormParser.parse(path: path, filename: "respostas.csv")

    maria = rows.find { |row| row.name.include?("Maria") }
    joao = rows.find { |row| row.name.include?("João") }

    assert_equal 2, rows.size
    assert_equal 20.0, maria.raw_score
    assert_equal "3ª Série N", joao.classroom_label
  ensure
    File.delete(path) if path && File.exist?(path)
  end
end
