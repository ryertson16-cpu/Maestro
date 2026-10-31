require "tempfile"
require "rqrcode"

module Documents
  class QrMark
    def initialize(url)
      @url = url.to_s
      @tempfiles = []
    end

    def draw(pdf, size: 64, url: @url, at: nil)
      @url = url.to_s
      file = png_file
      return unless file

      position = at || [pdf.bounds.width - size, pdf.cursor]
      pdf.image file.path, at: position, fit: [size, size]
    end

    def cleanup
      @tempfiles.each do |file|
        file.close
        file.unlink
      rescue StandardError
        nil
      end
    end

    private

    def png_file
      return if @url.blank?

      png = RQRCode::QRCode.new(@url, level: :l).as_png(
        bit_depth: 1,
        border_modules: 3,
        color_mode: ChunkyPNG::COLOR_GRAYSCALE,
        color: "000000",
        file: nil,
        fill: "ffffff",
        module_px_size: 16,
        resize_exactly_to: false,
        resize_gte_to: false,
        size: 512
      )

      tempfile = Tempfile.new(["maestro-qr", ".png"])
      tempfile.binmode
      tempfile.write(png.to_s)
      tempfile.flush
      @tempfiles << tempfile
      tempfile
    rescue StandardError => error
      Rails.logger.warn("[PDF] qr: #{error.class} #{error.message}")
      nil
    end
  end
end
