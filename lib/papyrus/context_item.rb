module Papyrus
  # A ContextItem embodies a scope where values are stored. You can retrieve and set
  # these values inside the ContextItem by name. All ContextItems have a parent,
  # so if we're looking for a value and can't find it we have another place to try.
  # An 'object' (either a hash, or an actual object) may also be bound to the
  # ContextItem which is a bit like using the JavaScript 'with' keyword.
  module ContextItem
    def self.included(klass)
      klass.class_eval do
        attr_accessor :object
        alias_method :[], :get
        alias_method :[]=, :set
        delegate :has_key?, :include?, :to => :vars
      end
    end

    # Searches for the given key in the values for this context or an ancestor context.
    #
    # If the key is a dot-separated set of words, we break the key into parts.
    # Starting with the first word, we resolve it, then use the resulting value to
    # resolve the second word (it can either refer to a hash key, array index, or
    # method of the value). We then use the value we get from that to resolve the next
    # word, continuing until we've resolved all the words. The final value is returned. 
    #
    # If the variable was found, its result will be returned. Otherwise,
    # UnknownVariableError is raised.
    #
    # Variables that start with a number are not resolved.
    #--
    # FIXME: This should not downcase the key before looking it up
    def get(key)
      key = key.to_s
      raise UnknownVariableError if key =~ /^\d/
      
      first, rest = key.split(".", 2)
      
      value = get_primary_part(first, key)
      return value unless rest && value
      
      key_parts = [first]
      value_so_far = value
      rest.split(".").each do |k|
        key_parts << k
        key_so_far = key_parts.join(".")
        value_so_far = get_secondary_part(key_so_far, k, value_so_far)
      end
      value_so_far
    end
    
    # Stores the given value in the context by the given key, case-insensitively.
    #--
    # FIXME: This should not downcase the key before storing it
    def set(key, value)
      vars[key.to_s.downcase] = value
    end

    # Removes the given variable from the context.
    def delete(key)
      vars.delete(key)
    end

    # Returns the variables stored with the context, or an empty hash if none have been defined.
    def vars
      @vars ||= {}
    end
    
    # Sets the hash of values within this context, converting keys to strings.
    def vars=(vars)
      @vars = vars.stringify_keys
    end

    # Returns the Parser whence this ContextItem came.
    # (Note that this is also a method in Node)
    def parser
      @parent && @parent.parser
    end

    # A convenience method to test whether the given variable (or value) has a true
    # value. Returns false if the given variable is not found in the context or has
    # a false value.
    def true?(var_or_value)
      !!get(var_or_value)
    end
    
  private
    def get_primary_part(key, whole_key)
      if vars.has_key?(key)
        vars[key]
      elsif @object.is_a?(Hash) && @object.has_key?(key)
        @object[key]
      elsif @object.is_a?(Hash) && @object.has_key?(key.to_sym)
        @object[key.to_sym]
      elsif @object.respond_to?(key.to_sym)
        @object.send(key)
      elsif @parent
        @parent.get(key)
      else
        raise UnknownVariableError
      end 
    end
    
    def get_secondary_part(key_so_far, key, value_so_far)
      if vars.has_key?(key_so_far)
        vars[key_so_far]
      elsif value_so_far.is_a?(Hash)
        value_so_far[key]
      elsif value_so_far.is_a?(Array) && key =~ /^\d+$/ # Array
        value_so_far[key.to_i]
      elsif value_so_far.respond_to?(key) # Just a method
        value_so_far.send(key)
      else
        raise UnknownVariableError
      end
    end
    
    #### If we ever re-enable this, also re-enable #get in BlockCommand ####
    ## Hack to get around the fact that BlockCommand#get overrides get to use
    ## active_block.get. In that case  we need to call the original get, otherwise we
    ## may very well have an infinite loop.
    #def parent_get(key)
    #  return unless parent
    #  parent.is_a?(BlockCommand) ? parent._get(key) : parent.get(key)
    #end
  end
end