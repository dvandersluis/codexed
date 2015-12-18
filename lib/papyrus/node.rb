module Papyrus
  # When the template is analyzed, it is split up into a set of nodes. A Node is
  # basically something that can be converted into a string using its +evaluate+
  # method. It may represent a command (i.e. a function), or a variable, or just plain
  # text. In addition, every Node may be tied to a parent Node, since we may need to
  # climb up the node ancestry for information.
  class Node
    attr_accessor :parent, :old_parent
    delegate :get, :to => :@parent
    delegate :parser, :document, :template, :to => :@parent, :allow_nil => true
    
    # Subclasses of Node use the evaluate method to generate their text output.
    # This method should *always* return a string.
    def evaluate
      raise NotImplementedError, 'Node#evaluate must be implemented by a subclass'
    end
    
    #def inspect
    #  vars = inspectable_instance_variables.map {|x| [x, instance_variable_get(x).inspect].join("=") }
    #  "#<%s:0x%x %s>" % [ self.class, self.object_id, vars.join(" ") ]
    #end
    
    def pretty_print_instance_variables
      self.instance_variables.sort - ["@document", "@parser", "@template", "@parent"]
    end
  end
end