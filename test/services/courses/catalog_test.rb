require "test_helper"

class CoursesCatalogTest < ActiveSupport::TestCase
  test "catalog includes the four BNCC areas and chemistry" do
    grouped = Courses::Catalog.grouped(include_technical_base: false)

    assert grouped.key?("linguagens_e_codigos")
    assert grouped.key?("ciencias_humanas")
    assert grouped.key?("ciencias_da_natureza")
    assert grouped.key?("matematica")
    assert_not grouped.key?("base_tecnica")
    assert_includes grouped["ciencias_da_natureza"].map(&:name), "Química"
    assert_includes grouped["linguagens_e_codigos"].map(&:name), "Língua Portuguesa"
  end

  test "technical base is listed only when requested" do
    grouped = Courses::Catalog.grouped(include_technical_base: true)

    assert grouped.key?("base_tecnica")
    assert_includes grouped["base_tecnica"].map(&:name), "Informática"
  end
end
