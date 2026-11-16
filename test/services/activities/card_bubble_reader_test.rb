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

  test "reads a filled bubble that sits a little off the expected center" do
    grid = Activities::BubbleGrid.new(1, %w[A B])
    width = 420
    height = (width * Activities::BubbleGrid::CARD_H / Activities::BubbleGrid::CARD_W).round
    image = ChunkyPNG::Image.new(width, height, ChunkyPNG::Color::WHITE)
    grid.fiducials.each do |nx, ny|
      paint_square(image, nx * width, ny * height, 16)
    end
    ax, ay = grid.bubbles.fetch("1").fetch("A")
    paint_disk(image, (ax * width) + 12, ay * height, 9)

    path = Rails.root.join("tmp/bubble-offset-#{SecureRandom.hex(4)}.png").to_s
    image.save(path)
    result = Activities::CardBubbleReader.read(path, question_count: 1, letters: %w[A B])

    assert_equal "A", result.answers["1"]
  ensure
    File.delete(path) if path && File.exist?(path)
  end

  test "reads the filled letter inside the printed rings when the grid is shifted" do
    letters = %w[A B C D E]
    grid = Activities::BubbleGrid.new(4, letters)
    width = 640
    height = (width * Activities::BubbleGrid::CARD_H / Activities::BubbleGrid::CARD_W).round
    image = ChunkyPNG::Image.new(width, height, ChunkyPNG::Color::WHITE)
    grid.fiducials.each do |nx, ny|
      paint_square(image, nx * width, ny * height, 18)
    end
    first = grid.bubbles.fetch("1")
    ax, = first.fetch("A")
    bx, = first.fetch("B")
    pitch = ((bx - ax).abs * width)
    ring = pitch * 0.21
    shift = 8
    grid.bubbles.each do |number, points|
      points.each do |letter, (nx, ny)|
        cx = (nx * width) + shift
        cy = ny * height
        paint_ring(image, cx, cy, ring)
        paint_disk(image, cx, cy, ring * 0.72) if number == "2" && letter == "D"
      end
    end

    path = Rails.root.join("tmp/bubble-rings-#{SecureRandom.hex(4)}.png").to_s
    image.save(path)
    result = Activities::CardBubbleReader.read(path, question_count: 4, letters: letters)

    assert_equal({ "2" => "D" }, result.answers)
  ensure
    File.delete(path) if path && File.exist?(path)
  end

  test "does not read a light smudge as a filled bubble" do
    grid = Activities::BubbleGrid.new(1, %w[A B])
    width = 420
    height = (width * Activities::BubbleGrid::CARD_H / Activities::BubbleGrid::CARD_W).round
    image = ChunkyPNG::Image.new(width, height, ChunkyPNG::Color::WHITE)
    grid.fiducials.each do |nx, ny|
      paint_square(image, nx * width, ny * height, 16)
    end
    ax, ay = grid.bubbles.fetch("1").fetch("A")
    paint_disk(image, ax * width, ay * height, 9, ChunkyPNG::Color.rgb(168, 168, 168))

    path = Rails.root.join("tmp/bubble-smudge-#{SecureRandom.hex(4)}.png").to_s
    image.save(path)
    result = Activities::CardBubbleReader.read(path, question_count: 1, letters: %w[A B])

    assert_nil result
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

  def paint_ring(image, cx, cy, radius)
    outer = radius * radius
    inner = [ radius - [ radius * 0.22, 1.2 ].max, 1 ].max
    hole = inner * inner
    (cy.round - radius.ceil).upto(cy.round + radius.ceil) do |y|
      (cx.round - radius.ceil).upto(cx.round + radius.ceil) do |x|
        next if x.negative? || y.negative? || x >= image.width || y >= image.height

        distance = ((x - cx)**2) + ((y - cy)**2)
        next unless distance <= outer && distance >= hole

        image[x, y] = ChunkyPNG::Color::BLACK
      end
    end
  end

  def paint_disk(image, cx, cy, radius, color = ChunkyPNG::Color.rgb(40, 20, 90))
    radius = radius.round
    (cy.round - radius).upto(cy.round + radius) do |y|
      (cx.round - radius).upto(cx.round + radius) do |x|
        next if x.negative? || y.negative? || x >= image.width || y >= image.height
        next if ((x - cx)**2) + ((y - cy)**2) > radius**2

        image[x, y] = color
      end
    end
  end
end
