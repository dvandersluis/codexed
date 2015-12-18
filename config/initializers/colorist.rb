module Colorist
  class Color
    def self.is_color_string?(some_string)
      return ( !/\A#([0-9a-f]{3}){1,2}\z/i.match(some_string).nil? or CSS_COLOR_NAMES.key?(some_string) )
    end
  end
end

class String
  def is_color?
    Colorist::Color.is_color_string?(self)
  end
end

class Object
  def to_color_string
    return self.to_s if self.to_s.is_color?

    if /\A[0-9a-f]\z/i.match(self.to_s)
      "##{self.to_s * 6}"
    elsif /\A[0-9a-f]{3}\z/i.match(self.to_s)
      "##{self.to_s * 2}"
    elsif /\A[0-9a-f]{6}\z/i.match(self.to_s)
      "##{self.to_s}"
    end
  end
end
