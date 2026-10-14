require "tempfile"
require "rqrcode"

module Documents
  class QrMark
    def initialize(url)
      @url = url.to_s
      @tempfiles = []
    end

    def draw(pdf, size: 64, url: @url)
      @url = url.to_s
      file = png_file
      return unless file

      pdf.image file.path, at: [pdf.bounds.width - size, pdf.cursor], fit: [size, size]
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

      png = RQRCode::QRCode.new(@url, level: :m).as_png(
        bit_depth: 1,
        border_modules: 1,
        color_mode: ChunkyPNG::COLOR_GRAYSCALE,
        color: "000",
        file: nil,
        fill: "fff",
        module_px_size: 6,
        resize_exactly_to: false,
        resize_gte_to: false,
        size: 240
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
