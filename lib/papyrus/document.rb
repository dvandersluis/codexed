module Papyrus
  # A Document represents the abstract syntax tree (AST) created during the parsing
  # process. It is responsible for evaluating the nodes in the AST and converting them
  # into a final string.
  class Document < NodeList
    # Note that this overrides #[] and #[]= in NodeList,
    # and also the #get that is in Node
    include ContextItem
    
    attr_accessor :parser
    
    delegate :template, :to => :@parser
    delegate :options, :vars, :to => :template
    
    # Creates a new Document, storing the parser the Document belongs to.
    def initialize(parser, nodes=[])
      super(nodes)
      @parser = parser
    end
        
    def document
      self
    end
    
    def pretty_print_instance_variables
      super - ["@parser", "@vars"]
    end
  end
end