module NumericScore
  module_function

  def recorded?(value)
    return false if value.nil?
    return false if value.is_a?(String) && value.strip.empty?

    true
  end

  def parse(value)
    return nil unless recorded?(value)

    value
  end

  def round_final(value)
    return unless recorded?(value)

    value.to_d.round(1, half: :up)
  end
end
