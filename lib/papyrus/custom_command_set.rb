module Papyrus
  # Custom commands are those which give you more flexibility over builtins as they let you
  # define any methods you want in a wrapper class that you can then mix into Papyrus's lexicon
  # at runtime. If a command is encountered in the template Papyrus will look for a corresponding
  # method in the wrapper class, calling it with the arguments of the command.
  #
  # Your wrapper class must inherit from CustomCommandSet, and then you pass an instance of it
  # to the Parser using its :custom_commands option.
  #
  # Custom commands can either be inline or block commands, which are located as methods in
  # a InlineCommands or BlockCommands module, respectively, inside your wrapper class.
  class CustomCommandSet
    class << self
      
      def command_properties 
        @command_properties ||= Hash.new { |h, k| h[k] = Hash.new }
      end
      
      def aliases
        @aliases ||= Hash.new
      end

      def alias_command(name, alias_name)
        aliases[alias_name.to_s.downcase] = name.to_s.downcase
      end

      def dont_pre_evaluate_args(*names)
        names.each do |name|
          command_properties[name.to_s.downcase][:pre_evaluate_args] = false 
        end
      end
      
      def has_inline_command?(name)
        return false unless defined? self::InlineCommands
        self::InlineCommands.instance_methods.include?(aliases[name.to_s.downcase] || name.to_s.downcase)
      end
      
      def has_block_command?(name)
        return false unless defined? self::BlockCommands
        self::BlockCommands.instance_methods.include?(aliases[name.to_s.downcase] || name.to_s.downcase)
      end
    end
    
    attr_reader :template, :args, :inner
    
    # Creates a new CustomCommandSet, storing the parser the CustomCommandSet belongs to
    # and the arguments to the command.
    def initialize(template, args=nil)
      @template = template
      @args = args || {}

      # Include the modules if they were defined
      self.class.class_eval do |klass|
        include self::InlineCommands if defined? self::InlineCommands
        include self::BlockCommands if defined? self::BlockCommands
      end   
    end
    
    # Called on #dup or #clone.
    def initialize_copy(set)
      @args = @args.clone

      # Include the modules if they were defined
      self.class.class_eval do |klass|
        include self::InlineCommands if defined? self::InlineCommands
        include self::BlockCommands if defined? self::BlockCommands
      end   
    end
    
    # Attempts to looks up the given inline command and call it.
    # If the command is not defined, #inline_command_missing is called instead.
    def __call_inline_command__(sub)
      name = self.class.aliases[sub.name.to_s.downcase] || sub.name.to_s.downcase
      pre_evaluate_args = self.class.command_properties[name][:pre_evaluate_args] === false
      args = pre_evaluate_args ? sub.orig_args : sub.evaluated_args

      if self.class.has_inline_command?(name)
        self.send(name, args)
      else
        inline_command_missing(name, args)
      end
    end
    
    # Attempts to looks up the given block command and call it.
    # If the command is not defined, #block_command_missing is called instead.
    def __call_block_command__(sub)
      name = self.class.aliases[sub.name.to_s.downcase] || sub.name.to_s.downcase
      pre_evaluate_args = self.class.command_properties[name][:pre_evaluate_args] === false
      args = pre_evaluate_args ? sub.orig_args : sub.evaluated_args
      inner = sub.evaluated_nodes

      if self.class.has_block_command?(name)
        self.send(name, args, inner)
      else
        block_command_missing(name, args, inner)
      end
    end
    
  protected
    # Called by the Parser if the inline command attempted to be called but was not defined.
    # Override to customize behavior. Remember to raise UnknownSubError or ParserError
    # if an error is encountered!
    def inline_command_missing(name, args)
      raise UnknownSubError
    end
    
    # Called by the Parser if the block command attempted to be called but was not defined.
    # Override to customize behavior. Remember to raise UnknownSubError or ParserError
    # if an error is encountered!
    def block_command_missing(name, args, inner)
      raise UnknownSubError
    end
  end
end
