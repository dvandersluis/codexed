module Papyrus
  # A Variable is a Node that represents a simple substitution (e.g. [foo]) that
  # could not be interpreted as a Command (because it doesn't exist or whatever).
  # We don't actually know if the variable exists, however, until we evaluate it.
  class Variable < Sub
    include InsertionSub
    
    # Creates a new Variable with the given name and raw representation of the variable.
    def initialize(name, raw_tokens)
      @name = name.downcase
      @raw_tokens = raw_tokens
    end
    
    # First we look for the variable in the parent context. If we don't find it,
    # then we simply return the raw sub. If we do, however, we first run the value
    # through the parser and insert the resulting nodes into the document that is
    # currently being evaluated. Assuming that the value doesn't have any subs in it,
    # we return the value. Note, however, that if this is a [body] sub, the value is
    # wrapped in a BodyString before being returned (so that it can be picked out later).
    def evaluate
      result = (@parent.get(@name) || "").to_s
      result = parse_and_insert_into_parent(result)
      # the following line only gets executed if the nodes weren't inserted for some reason
      # (e.g., the variable's value is empty or contains no subs)
      @name == "body" ? BodyString.new(result) : result
    rescue UnknownVariableError
      self.raw_sub
    end
    
    # Two variables are the same if they have the same name.
    def ==(other)
      other.is_a?(self.class) && @name == other.name
    end
  end
end
