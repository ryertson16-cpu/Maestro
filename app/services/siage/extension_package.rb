require "zip"

module Siage
  class ExtensionPackage
    ROOT = Rails.root.join("extensions/siage-presenca")
    SKIP_NAMES = %w[.DS_Store Thumbs.db].freeze

    def self.filename
      "siage-presenca-#{Siage::EXTENSION_VERSION}.zip"
    end

    def self.bytes
      new.to_zip
    end

    def to_zip
      buffer = Zip::OutputStream.write_buffer do |zip|
        files.each do |path|
          zip.put_next_entry(zip_entry_for(path))
          zip.write(File.binread(path))
        end
      end
      buffer.string
    end

    private

    def files
      ROOT.glob("**/*").select { |path| path.file? && SKIP_NAMES.exclude?(path.basename.to_s) }.sort
    end

    def zip_entry_for(path)
      "siage-presenca/#{path.relative_path_from(ROOT)}"
    end
  end
end
