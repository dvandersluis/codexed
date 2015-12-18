class Object
  # Default to_b function, override for different behavior
  def to_b
    self.to_s.to_b
  end
end
