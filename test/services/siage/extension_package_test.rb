require "test_helper"
require "zip"

class Siage::ExtensionPackageTest < ActiveSupport::TestCase
  def load_fixtures(_config = ActiveRecord::Base)
    {}
  end

  test "zip contains the unpacked extension folder" do
    names = []
    Zip::InputStream.open(StringIO.new(Siage::ExtensionPackage.bytes)) do |zip|
      while (entry = zip.get_next_entry)
        names << entry.name
      end
    end

    assert_includes names, "siage-presenca/manifest.json"
    assert_includes names, "siage-presenca/maestro-bridge.js"
    assert_equal "siage-presenca-#{Siage::EXTENSION_VERSION}.zip", Siage::ExtensionPackage.filename
  end
end
