module Activities
  class BubbleGrid
    CARD_W = 264.64
    CARD_H = 387.945

    def initialize(question_count, letters)
      @count = question_count.to_i
      @letters = Array(letters).map { |letter| letter.to_s.upcase }.presence || Question::LETTERS
    end

    def fiducials
      inset = 10.0
      [
        [ inset / CARD_W, inset / CARD_H ],
        [ (CARD_W - inset) / CARD_W, inset / CARD_H ],
        [ inset / CARD_W, (CARD_H - inset) / CARD_H ],
        [ (CARD_W - inset) / CARD_W, (CARD_H - inset) / CARD_H ]
      ]
    end

    def bubbles
      return {} if @count <= 0

      columns = 2
      per_col = (@count / columns.to_f).ceil
      grid_height = CARD_H - 168.0
      row_h = [ [ grid_height / [ per_col + 1, 1 ].max, 9 ].max, 13 ].min
      col_w = (CARD_W - 36.0) / columns
      label_w = 18.0
      step = (col_w - 8.0 - label_w) / [ @letters.size, 1 ].max
      first_image_y = 104.0

      mapped = {}
      @count.times do |index|
        column = index / per_col
        row = index % per_col
        left = 18.0 + (column * col_w)
        letters = {}
        @letters.each_with_index do |letter, letter_index|
          cx = left + label_w + (letter_index * step) + (step / 2.0)
          cy = first_image_y + (row * row_h)
          letters[letter] = [ cx / CARD_W, cy / CARD_H ]
        end
        mapped[(index + 1).to_s] = letters
      end
      mapped
    end
  end
end
