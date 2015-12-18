require 'has_strings'

class Country
  # Not an AR model, no associated table
  include HasStrings

  attr_accessor :id
  
  class << self
    def all
      self.strings.to_a.map{ |s| Country.new(s[0]) }
    end
  end

  def initialize(id)
    @id = id
  end
end
