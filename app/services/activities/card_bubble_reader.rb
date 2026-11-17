require "chunky_png"

module Activities
  class CardBubbleReader
    MAX_SIDE = 720
    DARK = 120

    def self.read(path, question_count:, letters:)
      new(path, question_count, letters).read
    end

    def initialize(path, question_count, letters)
      @path = path
      @grid = BubbleGrid.new(question_count, letters)
    end

    def read
      image = load_image
      return if image.nil?

      corners = find_corners(image)
      return if corners.nil?

      warp = Homography.between(@grid.fiducials, corners)
      return if warp.nil?

      aligned = align_grid(image, warp)
      answers = {}
      bubbles = {}
      @grid.bubbles.each do |number, letters|
        points = letters.map do |letter, point|
          x, y = aligned.image_point(point[0], point[1])
          bubbles[number] ||= {}
          bubbles[number][letter] = [ x / image.width.to_f, y / image.height.to_f ]
          { letter: letter, x: x, y: y }
        end
        radius = core_radius(image.width)
        samples = points.map do |point|
          reading = luminance_at(image, point[:x], point[:y], radius)
          { letter: point[:letter], lum: reading[:lum], ink: reading[:ink] }
        end
        chosen = chosen_letter(samples)
        answers[number] = chosen if chosen
      end
      return if answers.empty?

      AnswerCardVision::Result.new(name: nil, answers: answers, source: "local", bubbles: bubbles)
    rescue StandardError => error
      Rails.logger.warn("[card-bubbles] #{error.class}: #{error.message}")
      nil
    end

    private

    def load_image
      ChunkyPNG::Image.from_file(@path)
    rescue ChunkyPNG::Exception, ChunkyPNG::SignatureMismatch, ArgumentError, LoadError
      converted = Tempfile.new([ "cartao-leitura", ".png" ])
      pipeline = image_pipeline
      return if pipeline.nil?

      pipeline.resize_to_limit(MAX_SIDE, MAX_SIDE).convert("png").call(destination: converted.path)
      ChunkyPNG::Image.from_file(converted.path)
    rescue StandardError, LoadError
      nil
    ensure
      converted&.close
      converted&.unlink
    end

    def image_pipeline
      ImageProcessing::Vips.source(@path).auto_orient
    rescue LoadError, StandardError
      ImageProcessing::MiniMagick.source(@path).auto_orient
    rescue LoadError, StandardError
      nil
    end

    def find_corners(image)
      small, scale = shrink(image)
      blobs = dark_squares(small)
      return if blobs.size < 4

      width = small.width
      height = small.height
      corners = [
        [ 0, 0 ],
        [ width - 1, 0 ],
        [ 0, height - 1 ],
        [ width - 1, height - 1 ]
      ].filter_map.with_index do |(x, y), index|
        quadrant = blobs.select { |blob| blob_in_quadrant?(blob, index, width, height) }
        pool = quadrant.presence || blobs
        pool.min_by { |blob| (blob[:x] - x)**2 + (blob[:y] - y)**2 }
      end
      return if corners.uniq { |blob| [ blob[:x].round, blob[:y].round ] }.size < 4

      left = corners.map { |blob| blob[:x] }.min
      right = corners.map { |blob| blob[:x] }.max
      top = corners.map { |blob| blob[:y] }.min
      bottom = corners.map { |blob| blob[:y] }.max
      return if (right - left) < width * 0.18 || (bottom - top) < height * 0.18

      corners.map { |blob| [ blob[:x] / scale, blob[:y] / scale ] }
    end

    def blob_in_quadrant?(blob, index, width, height)
      case index
      when 0 then blob[:x] < width * 0.55 && blob[:y] < height * 0.55
      when 1 then blob[:x] > width * 0.45 && blob[:y] < height * 0.55
      when 2 then blob[:x] < width * 0.55 && blob[:y] > height * 0.45
      else blob[:x] > width * 0.45 && blob[:y] > height * 0.45
      end
    end

    def shrink(image)
      scale = [ 1.0, MAX_SIDE.to_f / [ image.width, image.height ].max ].min
      return [ image, 1.0 ] if scale > 0.98

      width = [ (image.width * scale).round, 1 ].max
      height = [ (image.height * scale).round, 1 ].max
      small = ChunkyPNG::Image.new(width, height, ChunkyPNG::Color::WHITE)
      width.times do |x|
        height.times do |y|
          small[x, y] = image[(x / scale).floor, (y / scale).floor]
        end
      end
      [ small, scale ]
    end

    def dark_squares(image)
      width = image.width
      height = image.height
      seen = Array.new(width * height, false)
      blobs = []
      height.times do |y|
        width.times do |x|
          index = (y * width) + x
          next if seen[index]
          next unless dark?(image[x, y])

          queue = [ [ x, y ] ]
          seen[index] = true
          count = 0
          sum_x = 0
          sum_y = 0
          min_x = x
          max_x = x
          min_y = y
          max_y = y
          while (point = queue.pop)
            px, py = point
            count += 1
            sum_x += px
            sum_y += py
            min_x = px if px < min_x
            max_x = px if px > max_x
            min_y = py if py < min_y
            max_y = py if py > max_y
            [
              [ px - 1, py ],
              [ px + 1, py ],
              [ px, py - 1 ],
              [ px, py + 1 ]
            ].each do |nx, ny|
              next if nx.negative? || ny.negative? || nx >= width || ny >= height

              neighbor = (ny * width) + nx
              next if seen[neighbor]
              next unless dark?(image[nx, ny])

              seen[neighbor] = true
              queue << [ nx, ny ]
            end
          end

          box_w = max_x - min_x + 1
          box_h = max_y - min_y + 1
          next if count < 24 || count > 12000
          next if box_w < 5 || box_h < 5
          ratio = box_w.to_f / box_h
          next unless ratio.between?(0.65, 1.45)
          next if count < (box_w * box_h) * 0.45

          blobs << { x: sum_x.to_f / count, y: sum_y.to_f / count, area: count }
        end
      end
      blobs
    end

    def chosen_letter(samples)
      ordered = samples.sort_by { |sample| [ -sample[:ink], sample[:lum] ] }
      best = ordered[0]
      second = ordered[1]
      return if best.nil?

      gap = best[:ink] - (second ? second[:ink] : 0)
      return best[:letter] if best[:ink] >= 0.62 && gap >= 0.22

      nil
    end

    def align_grid(image, warp)
      rows = @grid.bubbles.values
      return warp if rows.empty?

      score_at = lambda do |shift_x, shift_y|
        radius = core_radius(image.width)
        rows.sum do |letters|
          inks = letters.values.map do |point|
            x, y = warp.image_point(point[0], point[1])
            luminance_at(image, x + shift_x, y + shift_y, radius)[:ink]
          end.sort.reverse
          filled = inks.count { |ink| ink >= 0.62 }
          (filled * 2) + ((inks[0] || 0) - (inks[1] || 0))
        end
      end

      pitch = pitch_at(warp, 0, 0)
      row_gap = pitch
      if rows.size > 1
        first = rows[0].values.first
        second = rows[1].values.first
        ax, ay = warp.image_point(first[0], first[1])
        bx, by = warp.image_point(second[0], second[1])
        distance = Math.hypot(bx - ax, by - ay)
        row_gap = distance if distance > 4
      end
      limit = [ ( [ pitch, row_gap ].min * 0.4 ).round, 4 ].max
      step = [ (pitch * 0.08).round, 2 ].max
      best = { dx: 0, dy: 0, score: score_at.call(0, 0) }
      (-limit..limit).step(step) do |dy|
        (-limit..limit).step(step) do |dx|
          score = score_at.call(dx, dy)
          best = { dx: dx, dy: dy, score: score } if score > best[:score]
        end
      end
      fine = [ (step / 2.0).round, 1 ].max
      found = best.dup
      (found[:dy] - step..found[:dy] + step).step(fine) do |dy|
        (found[:dx] - step..found[:dx] + step).step(fine) do |dx|
          next if dx.abs > limit || dy.abs > limit

          score = score_at.call(dx, dy)
          best = { dx: dx, dy: dy, score: score } if score > best[:score]
        end
      end
      ShiftedWarp.new(warp, best[:dx], best[:dy])
    end

    def pitch_at(warp, shift_x, shift_y)
      points = @grid.bubbles.values.first.to_a.map do |letter, point|
        x, y = warp.image_point(point[0], point[1])
        { letter: letter, x: x + shift_x, y: y + shift_y }
      end
      letter_pitch(points)
    end

    def core_radius(width)
      bubble = (3.8 / BubbleGrid::CARD_W) * width
      [ (bubble * 0.55).round, 2 ].max
    end

    def letter_pitch(points)
      pitch = nil
      points.each_cons(2) do |first, second|
        distance = Math.hypot(second[:x] - first[:x], second[:y] - first[:y])
        pitch = distance if distance > 4 && (pitch.nil? || distance < pitch)
      end
      pitch || 48.0
    end

    def luminance_at(image, x, y, radius)
      values = []
      quads = Array.new(4) { [] }
      cx = x.round
      cy = y.round
      limit = radius * radius
      (-radius..radius).each do |dy|
        (-radius..radius).each do |dx|
          next if (dx * dx) + (dy * dy) > limit

          px = cx + dx
          py = cy + dy
          next if px.negative? || py.negative? || px >= image.width || py >= image.height

          value = luminance(image[px, py])
          values << value
          quads[(dx >= 0 ? 1 : 0) + (dy >= 0 ? 2 : 0)] << value
        end
      end
      return { lum: 255, ink: 0.0 } if values.empty?

      values.sort!
      dark_share = ->(bucket) { bucket.empty? ? 0.0 : bucket.count { |item| item <= 155 }.to_f / bucket.size }
      dark = dark_share.call(values)
      lum = values[((values.size - 1) * 0.35).round]
      filled = lum <= 150 && dark >= 0.62 && quads.all? { |bucket| !bucket.empty? && dark_share.call(bucket) >= 0.45 }
      { lum: lum, ink: filled ? dark : 0.0 }
    end

    def dark?(color)
      luminance(color) <= DARK
    end

    def luminance(color)
      (ChunkyPNG::Color.r(color) + ChunkyPNG::Color.g(color) + ChunkyPNG::Color.b(color)) / 3
    end

    class ShiftedWarp
      def initialize(warp, dx, dy)
        @warp = warp
        @dx = dx
        @dy = dy
      end

      def image_point(x, y)
        px, py = @warp.image_point(x, y)
        [ px + @dx, py + @dy ]
      end
    end

    class Homography
      def self.between(sources, destinations)
        matrix = []
        vector = []
        sources.each_with_index do |(x, y), index|
          u, v = destinations[index]
          matrix << [ x, y, 1, 0, 0, 0, -x * u, -y * u ]
          vector << u
          matrix << [ 0, 0, 0, x, y, 1, -x * v, -y * v ]
          vector << v
        end
        solved = solve(matrix, vector)
        return if solved.nil?

        new(solved)
      end

      def initialize(coefficients)
        @h = coefficients
      end

      def image_point(x, y)
        denom = (@h[6] * x) + (@h[7] * y) + 1.0
        return [ 0, 0 ] if denom.abs < 1e-8

        [
          ((@h[0] * x) + (@h[1] * y) + @h[2]) / denom,
          ((@h[3] * x) + (@h[4] * y) + @h[5]) / denom
        ]
      end

      def self.solve(rows, vector)
        size = vector.size
        matrix = rows.map.with_index { |row, index| row.dup << vector[index].to_f }
        size.times do |col|
          pivot = (col...size).max_by { |row| matrix[row][col].abs }
          return if pivot.nil? || matrix[pivot][col].abs < 1e-8

          matrix[col], matrix[pivot] = matrix[pivot], matrix[col]
          factor = matrix[col][col]
          matrix[col].map! { |value| value / factor }
          size.times do |row|
            next if row == col

            scale = matrix[row][col]
            next if scale.abs < 1e-12

            matrix[row].each_index { |index| matrix[row][index] -= scale * matrix[col][index] }
          end
        end
        matrix.map { |row| row[size] }
      end
    end
  end
end
