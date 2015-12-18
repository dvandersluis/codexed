module Papyrus
  class InlineSub < Sub
    attr_reader :orig_args, :evaluated_args
    
    # Resolves the sub and returns the result. This is where we determine what
    # exactly the Sub actually represents: whether it's a built-in command, a custom
    # command, a variable - or whether it in fact doesn't resolve to anything.
    #
    # If the sub can be resolved, before the result is returned, we update the
    # raw token list to contain merely the result so that if an outer sub cannot
    # be resolved, the result of this sub will still be retained. This works because
    # there's actually a reference to this raw tokens object in the raw tokens array
    # of the parent sub, and so changing this object changes that one (and any other
    # references up the ancestry chain) too. Neat, eh?
    def evaluate
      # since evaluating a NodeList can possibly mutate it, back it up
      @orig_args = @args.clone
      @evaluated_args = @args.to_a
    
      if evaluate? && evaluates_as_inline_command_or_variable?
        @raw_tokens.replace([ Token::Text.new(@result) ])
        return @result
      else
        return raw_sub
      end
    end
    
    #def pretty_print_instance_variables
    #  super + ["@orig_args", "@evaluated_args"]
    #end
  
  protected
    def evaluates_as_inline_command_or_variable?
      evaluates_as_builtin_command? or evaluates_as_custom_inline_command? or evaluates_as_variable?
    end
  
    def evaluates_as_builtin_command?
      # this isn't strictly inline, but right now we only have one built-in command
      # and it's inline... in short, FIXME later
      if command_allowed? and cmd_class = Papyrus::Lexicon.commands[@name]
        cmd = cmd_class.new(@name, @orig_args, @raw_tokens)
        cmd.parent = @parent
        cmd.wrapper = self
        @result = cmd.evaluate
        return true
      else
        return false
      end
    rescue ParserError => e
      return false
    end
  
    def evaluates_as_custom_inline_command?
      if command_allowed? && self.template.custom_commands
        @result = self.template.custom_commands.__call_inline_command__(self)
        return true
      else
        return false
      end
    rescue ParserError => e
      return false
    end
  end
end