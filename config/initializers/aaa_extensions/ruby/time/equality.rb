class Time
  def ==(other_time)
    other_time.is_a?(Time) ? self.to_i == other_time.to_i : nil
  end
end