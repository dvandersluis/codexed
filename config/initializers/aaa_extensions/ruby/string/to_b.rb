class String
  def to_b
    return false if self.empty?
    %w(false f 0).include?(self.downcase) ? false : true
  end
end
