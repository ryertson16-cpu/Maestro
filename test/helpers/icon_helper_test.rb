require "test_helper"

class IconHelperTest < ActionView::TestCase
  def load_fixtures(_config = ActiveRecord::Base)
    {}
  end

  test "lote 1 usa SVG no estilo daisyUI, nao PNG" do
    %i[search user lock mail eye eye_off sun moon bell arrow check warning avisos].each do |name|
      html = maestro_icon(name)

      assert_includes html, "<svg"
      assert_not_includes html, ".png"
    end
  end

  test "lote 2 do menu e titulos usa SVG, nao PNG" do
    %i[diary classrooms activities clipboard students monitoring projects courses].each do |name|
      html = maestro_icon(name)

      assert_includes html, "<svg"
      assert_not_includes html, ".png"
    end
  end

  test "SIAGE usa SVG de envio, nao PNG" do
    html = maestro_icon(:siage)

    assert_includes html, "<svg"
    assert_includes html, "M4 16v1a3 3 0 003 3h10"
    assert_not_includes html, ".png"
  end

  test "sino da navbar daisyUI e sol/lua preenchidos do swap" do
    bell = maestro_icon(:bell)
    sun = maestro_icon(:sun)
    search = maestro_icon(:search)

    assert_includes bell, "M15 17h5l-1.405"
    assert_includes sun, 'fill="currentColor"'
    assert_includes search, 'stroke-width="2"'
  end
end
