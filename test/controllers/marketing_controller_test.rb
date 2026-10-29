require "test_helper"
require "zip"

class MarketingControllerTest < ActionDispatch::IntegrationTest
  def load_fixtures(_config = ActiveRecord::Base)
    {}
  end

  test "visitante vê a vitrine em /" do
    get root_path

    assert_response :success
    assert_includes response.body, "O caderno que"
    assert_includes response.body, "Criar conta"
    assert_includes response.body, "SIAGE"
    assert_includes response.body, "fonts.googleapis.com"
    assert_includes response.body, "family=Inter"
    assert_includes response.body, "family=Outfit"
    assert_includes response.body, "Baixar extensão SIAGE"
    assert_includes response.body, download_siage_extension_path
  end

  test "visitante baixa o zip da extensao SIAGE" do
    get download_siage_extension_path

    assert_response :success
    assert_equal "application/zip", response.media_type
    assert_match(/siage-presenca-#{Regexp.escape(Siage::EXTENSION_VERSION)}\.zip/, response.headers["Content-Disposition"])

    entries = zip_entries(response.body)
    assert_includes entries.keys, "siage-presenca/manifest.json"
    assert_includes entries["siage-presenca/manifest.json"], "cadernomaestro.com.br"
  end

  test "pagina baixar ensina a instalar a extensao" do
    get download_maestro_path

    assert_response :success
    assert_includes response.body, "Baixar extensão SIAGE"
    assert_includes response.body, "Modo do desenvolvedor"
  end

  private

  def zip_entries(bytes)
    files = {}
    Zip::InputStream.open(StringIO.new(bytes)) do |zip|
      while (entry = zip.get_next_entry)
        files[entry.name] = zip.read.to_s
      end
    end
    files
  end
end
