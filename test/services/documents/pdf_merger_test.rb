require "test_helper"
require "prawn"
require "zlib"

class Documents::PdfMergerTest < ActiveSupport::TestCase
  def load_fixtures(_config = ActiveRecord::Base)
    {}
  end

  test "joins student packets and keeps each page" do
    left = Tempfile.new([ "esquerda", ".pdf" ])
    right = Tempfile.new([ "direita", ".pdf" ])
    left.binmode
    right.binmode
    Prawn::Document.generate(left.path) do |pdf|
      pdf.text "ESQUERDA"
      pdf.image StringIO.new(sample_png), width: 30
    end
    Prawn::Document.generate(right.path) do |pdf|
      pdf.text "DIREITA"
      pdf.start_new_page
      pdf.text "FIM"
    end

    merged = Documents::PdfMerger.join([ left.path, right.path ])
    reader = PDF::Reader.new(StringIO.new(merged))
    text = reader.pages.map(&:text).join("\n")

    assert_equal 3, reader.page_count
    assert_includes text, "ESQUERDA"
    assert_includes text, "DIREITA"
    assert_includes text, "FIM"
    assert reader.page(1).raw_content.include?("/I1 Do")
  ensure
    left&.close
    left&.unlink
    right&.close
    right&.unlink
  end

  def sample_png
    raw = Array.new(8) { "\x00".b + ("\x80".b * 24) }.join
    chunk = lambda do |type, data|
      [ data.bytesize ].pack("N") + type + data + [ Zlib.crc32(type + data) ].pack("N")
    end
    ihdr = [ 8, 8, 8, 2, 0, 0, 0 ].pack("NNCCCCC")
    "\x89PNG\r\n\x1A\n".b + chunk.call("IHDR", ihdr) + chunk.call("IDAT", Zlib::Deflate.deflate(raw)) + chunk.call("IEND", "")
  end
end
