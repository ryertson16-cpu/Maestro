require "test_helper"
require "zip"

class Siage::ExtensionPackageTest < ActiveSupport::TestCase
  def load_fixtures(_config = ActiveRecord::Base)
    {}
  end

  test "zip contains the unpacked extension folder" do
    names = []
    manifest = nil
    Zip::InputStream.open(StringIO.new(Siage::ExtensionPackage.bytes)) do |zip|
      while (entry = zip.get_next_entry)
        names << entry.name
        manifest = entry.get_input_stream.read if entry.name == "siage-presenca/manifest.json"
      end
    end

    assert_includes names, "siage-presenca/manifest.json"
    assert_includes names, "siage-presenca/maestro-bridge.js"
    assert_equal "siage-presenca-#{Siage::EXTENSION_VERSION}.zip", Siage::ExtensionPackage.filename
    assert_includes manifest, "cadernomaestro.com.br"
    assert_not_includes manifest, "onrender.com"
  end
end
