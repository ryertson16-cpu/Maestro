require "chunky_png"

module Activities
  class CardMarkOverlay
    COLORS = {
      hit: ChunkyPNG::Color.rgba(34, 197, 94, 200),
      miss: ChunkyPNG::Color.rgba(239, 68, 68, 200),
      blank: ChunkyPNG::Color.rgba(59, 130, 246, 200)
    }.freeze

    RING = ChunkyPNG::Color.rgba(255, 255, 255, 220)

    def self.render(path, marks)
      new(path, marks).render
    end

    def initialize(path, marks)
      @path = path
      @marks = Array(marks)
    end

    def render
      return if @path.blank? || !File.file?(@path)
      return if @marks.empty?

      image = load_image
      return unless image

      radius = [10, (image.width * 0.022).round].max
      @marks.each do |mark|
        x = (mark[:x].to_f * image.width).round
        y = (mark[:y].to_f * image.height).round
        fill = COLORS[mark[:kind]] || COLORS[:blank]
        image.circle(x, y, radius + 2, RING, RING)
        image.circle(x, y, radius, fill, fill)
      end

      file = Tempfile.new(["cartao-marcado", ".png"])
      file.binmode
      image.save(file.path)
      file.flush
      file
    rescue StandardError => error
      Rails.logger.warn("[card-mark] #{error.class}: #{error.message}")
      nil
    end

    private

    def load_image
      ChunkyPNG::Image.from_file(@path)
    rescue ChunkyPNG::Exception, ChunkyPNG::SignatureMismatch, ArgumentError
      convert_with_processor
    end

    def convert_with_processor
      return unless defined?(ImageProcessing)

      converted = Tempfile.new(["cartao", ".png"])
      pipeline = if defined?(ImageProcessing::Vips)
        ImageProcessing::Vips.source(@path)
      else
        ImageProcessing::MiniMagick.source(@path)
      end
      pipeline.convert("png").call(destination: converted.path)
      ChunkyPNG::Image.from_file(converted.path)
    rescue StandardError
      nil
    ensure
      converted&.close
      converted&.unlink
    end
  end
end
