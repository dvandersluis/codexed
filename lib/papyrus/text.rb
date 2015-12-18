module Papyrus
  # Text is a very simple Node which evaluates to the string it stores.
  class Text < Node
    attr_reader :text
    
    # Creates a new Text node, storing the given text.
    def initialize(text)
      @text = text.to_s
    end

    # Just returns the text given to Text.new.
    def evaluate
      # make a new object here so that when we build strings in NodeList#evaluate
      # we don't end up passing references around and destructively modifying strings that
      # originated all the way over here
      @text.dup
    end
    
    def to_s
      @text
    end
    
    # for testing
    def ==(other)
      other.is_a?(Text) && self.text == other.text
    end
    
    #def inspect
    #  vars = inspectable_instance_variables.map do |x|
    #    val = instance_variable_get(x)
    #    val = val[0..20] + "..." if x == "@text" && val.length > 20
    #    [x, val.inspect].join("=")
    #  end
    #  "#<%s:0x%x %s>" % [ self.class, self.object_id, vars.join(" ") ]
    #end
  end
end