require "test_helper"
require "chunky_png"

class Activities::CardBubbleReaderTest < ActiveSupport::TestCase
  def load_fixtures(_config = ActiveRecord::Base)
    {}
  end

  test "reads the filled bubble from the card marks" do
    grid = Activities::BubbleGrid.new(1, %w[A B])
    width = 420
    height = (width * Activities::BubbleGrid::CARD_H / Activities::BubbleGrid::CARD_W).round
    image = ChunkyPNG::Image.new(width, height, ChunkyPNG::Color::WHITE)
    grid.fiducials.each do |nx, ny|
      paint_square(image, nx * width, ny * height, 16)
    end
    ax, ay = grid.bubbles.fetch("1").fetch("A")
    paint_disk(image, ax * width, ay * height, 9)

    path = Rails.root.join("tmp/bubble-card-#{SecureRandom.hex(4)}.png").to_s
    image.save(path)
    result = Activities::CardBubbleReader.read(path, question_count: 1, letters: %w[A B])

    assert_equal "local", result.source
    assert_equal "A", result.answers["1"]
    assert_nil result.answers["2"]
  ensure
    File.delete(path) if path && File.exist?(path)
  end

  def paint_square(image, cx, cy, size)
    half = size / 2
    (cy.round - half).upto(cy.round + half) do |y|
      (cx.round - half).upto(cx.round + half) do |x|
        next if x.negative? || y.negative? || x >= image.width || y >= image.height

        image[x, y] = ChunkyPNG::Color::BLACK
      end
    end
  end

  def paint_disk(image, cx, cy, radius)
    (cy.round - radius).upto(cy.round + radius) do |y|
      (cx.round - radius).upto(cx.round + radius) do |x|
        next if x.negative? || y.negative? || x >= image.width || y >= image.height
        next if ((x - cx)**2) + ((y - cy)**2) > radius**2

        image[x, y] = ChunkyPNG::Color.rgb(40, 20, 90)
      end
    end
  end
end
