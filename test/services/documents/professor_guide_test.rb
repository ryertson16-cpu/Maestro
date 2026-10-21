require "test_helper"

class Documents::ProfessorGuideTest < ActiveSupport::TestCase
  def load_fixtures(_config = ActiveRecord::Base)
    {}
  end

  test "renders a Portuguese PDF guide" do
    pdf = Documents::ProfessorGuide.new.render

    assert_operator pdf.bytesize, :>, 4_000
    assert_match(/%PDF/, pdf[0, 8])

    text = PDF::Reader.new(StringIO.new(pdf)).pages.map(&:text).join(" ")
    assert_match(/Aviso do grupo/, text)
    assert_match(/Solid Queue/, text)
    assert_match(/SIAGE Presença Automática/, text)
  end
end
