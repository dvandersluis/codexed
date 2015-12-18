module Papyrus
  class Lexicon
    
    @@commands = {}
    cattr_reader :commands
    
    @@extensions = []
    cattr_reader :extensions
    
    class << self
      # Adds the name of a command along with the class that represents that command
      # to the global commands hash.
      def add_command(name, klass)
        @@commands[name] = klass
      end
    
      # Given a module that contains classes representing commands, adds the commands
      # to the lexicon. The name of the command is derived from the name of the class
      # (so an Include class would be assumed to represent the 'include' command).
      def extend_lexicon(mod)
        return if @@extensions.include?(mod)
        mod.constants.each do |constant|
          command_name = constant.downcase
          command_class = mod.const_get(constant)
          next unless Class === command_class
          add_command(command_name, command_class)
        end
        @@extensions << mod
      end
    end
    
  end
end