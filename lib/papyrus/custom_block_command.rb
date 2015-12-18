module Papyrus
  class CustomBlockCommand < BlockCommand
    attr_reader :orig_args, :evaluated_args, :orig_nodes, :evaluated_nodes
    
    def initialize(*args)
      super
      @nodes = NodeList.new
      @nodes.parent = self
    end
  
    def active_block
      @nodes
    end
  
    def evaluate
      # since evaluating a NodeList can possibly mutate it, back it up
      @orig_args = @args.clone
      @evaluated_args = @args.to_a
      @orig_nodes = @nodes.clone
      @evaluated_nodes = @nodes.evaluate.to_s
    
      if evaluate? && evaluates_as_command_or_variable?
        @raw_tokens.replace([ Token::Text.new(@result) ])
        return @result
      else
        return raw_sub
      end
    end
    
    def pretty_print_instance_variables
      super + ["@nodes"]
    end
  
  protected
    def evaluates_as_command_or_variable?
      evaluates_as_custom_block_command? or evaluates_as_variable?
    end
  
    def evaluates_as_custom_block_command?
      if command_allowed? && self.template.custom_commands.class.has_block_command?(@name)
        @result = self.template.custom_commands.__call_block_command__(self)
        return true
      else
        return false
      end
    rescue ParserError => e
      #Papyrus.debug("#{e.class}: #{e.message}")
      #Papyrus.debug(e.backtrace.join("\n"))
      return false
    end
  end
end