module Papyrus
  # A BlockCommand is a command that has a start tag, an end tag, and possibly
  # modifier tags. The content between tags may span multiple lines, and contain
  # subs itself.
  #
  # A BlockCommand is also a context object, not so much for storing values but for
  # ease in retrieving them from ancestors.
  class BlockCommand < Command
    include ContextItem
    
    delegate :add, :<<, :to => :active_block
    
    # Creates a new instance of the BlockCommand.
    def initialize(*args)
      raise TypeError, 'BlockCommand.new should not be called directly' if self.class == BlockCommand
      super
    end
    
    # Since BlockCommands have the ability to contain multiple blocks, returns
    # the block that we're currently inside. You should define this method in subclasses
    # of BlockCommand. It should return a NodeList.
    def active_block
      raise NotImplementedError, 'BlockCommand#active_block should be overridden by a subclass'
    end
    
    #### If we ever re-enable this, also re-enable #parent_get in ContextItem ####
    ## BlockCommand#_get is Command#get
    #alias_method :_get, :get
    ## Gets the given variable from the active block.
    #def get(key)
    #  active_block.get(key)
    #end
    
    def to_s
      "[ #{@name} ]"
    end
  end
end