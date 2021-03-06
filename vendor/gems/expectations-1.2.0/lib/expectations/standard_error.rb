class Expectations::StandardError
  class << self
    attr_accessor :outlet
  end
  
  self.outlet = STDERR
  
  def self.silence
    self.outlet = Silent
  end
  
  def self.print(string)
    print_suggestion
    outlet.print string
  end
  
  def self.print_suggestion
    return if @suggestion_printed
    @suggestion_printed = true
    outlet.print "Expectations allows you to to create multiple mock expectations, but suggests that you write another test instead.\n"
  end
end