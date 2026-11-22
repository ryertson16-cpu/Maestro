module Documents
  class ColumnImage
    READABLE_HEIGHT = 100
    MAX_SLICES = 4

    def self.draw(pdf, source)
      path = materialize(pdf, source)
      return if path.blank?

      pixels_w, pixels_h = pixels(path)
      count = slice_count(pixels_w, pixels_h, pdf.bounds.width)
      if count <= 1
        pdf.image path, fit: fit_box(pdf.bounds.width)
        return
      end

      regions(pixels_w, count).each_with_index do |(left, slice_px), index|
        continuation(pdf) if index.positive?
        draw_slice(pdf, path, pixels_w, pixels_h, left, slice_px)
      end
    end

    def self.slice_count(pixels_w, pixels_h, column_width)
      return 1 if pixels_w.to_i <= 0 || pixels_h.to_i <= 0
      return 1 if column_width.to_f >= 420
      return 1 if pixels_w <= pixels_h

      shown = pixels_h.to_f * [ column_width.to_f / pixels_w, 1 ].min
      return 1 if shown >= READABLE_HEIGHT

      count = (READABLE_HEIGHT / shown).ceil
      [ [ count, MAX_SLICES ].min, 2 ].max
    end

    def self.regions(pixels_w, count)
      step = pixels_w.to_f / count
      overlap = 16
      count.times.map do |index|
        left = [ (index * step).floor - (index.positive? ? overlap : 0), 0 ].max
        right = index == count - 1 ? pixels_w : [ ((index + 1) * step).ceil + overlap, pixels_w ].min
        [ left, [ right - left, 1 ].max ]
      end
    end

    def self.draw_slice(pdf, path, pixels_w, pixels_h, left, slice_px)
      column_width = pdf.bounds.width
      scale = column_width / slice_px.to_f
      display_h = pixels_h * scale
      pdf.bounding_box([ 0, pdf.cursor ], width: column_width, height: display_h) do
        pdf.save_graphics_state do
          pdf.rectangle [ 0, 0 ], column_width, display_h
          pdf.add_content "W n"
          pdf.image path, width: pixels_w * scale, at: [ -(left * scale), pdf.bounds.top ]
        end
      end
    end

    def self.continuation(pdf)
      pdf.move_down 2
      pdf.fill_color "707891"
      pdf.text "continuação à direita", size: 7
      pdf.fill_color "20263D"
      pdf.move_down 2
    end

    def self.fit_box(width)
      width.to_f < 420 ? [ width, 260 ] : [ width, 420 ]
    end

    def self.materialize(pdf, source)
      return source.to_s if path_source?(source)

      bytes = source.to_s.b
      return if bytes.blank?

      ext = bytes.start_with?("\x89PNG".b) ? ".png" : ".jpg"
      file = Tempfile.new([ "maestro-quadro", ext ])
      file.binmode
      file.write(bytes)
      file.flush
      sheet = Thread.current[:maestro_sheet]
      if sheet
        sheet.send(:keep_image_file, file)
      else
        kept = pdf.instance_variable_get(:@maestro_kept_files) || []
        kept << file
        pdf.instance_variable_set(:@maestro_kept_files, kept)
      end
      file.path
    end

    def self.path_source?(source)
      path = source.is_a?(Pathname) ? source.to_s : source
      return false unless path.is_a?(String)
      return false if path.bytesize > 1024 || path.include?("\x00")

      File.file?(path)
    rescue StandardError
      false
    end

    def self.pixels(path)
      header = File.binread(path, 524_288).to_s.b
      return header.byteslice(16, 8).unpack("NN") if header.start_with?("\x89PNG".b)
      return jpeg_pixels(StringIO.new(header)) if header.start_with?("\xFF\xD8".b)

      [ 0, 0 ]
    rescue StandardError
      [ 0, 0 ]
    end

    def self.jpeg_pixels(file)
      file.rewind
      file.read(2)
      while !file.eof?
        marker = file.read(2)
        break unless marker&.start_with?("\xFF".b)

        code = marker.getbyte(1)
        length = file.read(2)&.unpack1("n").to_i
        break if length < 2
        if [ 0xC0, 0xC1, 0xC2 ].include?(code)
          file.read(1)
          height, width = file.read(4).unpack("nn")
          return [ width, height ]
        end
        file.seek(length - 2, IO::SEEK_CUR)
      end
      [ 0, 0 ]
    end

    private_class_method :draw_slice, :continuation, :fit_box, :materialize, :path_source?, :pixels, :jpeg_pixels
  end
end
