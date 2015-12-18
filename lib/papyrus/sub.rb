module Papyrus
  class Sub < Node
    attr_reader :name, :args, :raw_tokens
    attr_accessor :wrapper
    
    # Creates a new Sub. The first argument is the name of the sub as a string.
    # Second argument is a NodeList representing the arguments of the sub.
    # Third argument is a TokenList that represents the Sub (and is generated during
    # the tokenizing process).
    def initialize(name, args, raw_tokens)
      @name = name.downcase
      @args = args
      @args.parent = self
      @raw_tokens = raw_tokens
    end
    
    # Called on #dup or #clone.
    def initialize_copy(sub)
      @args = @args.clone
      @args.parent = self
      @raw_tokens = @raw_tokens.clone
    end
    
    # Returns false if any of this sub's ancestors have been specified as being shielded,
    # otherwise returns true. So if you had [entrylist "[time]"] and [entrylist] were
    # specified as being shielded, then [time]'s #evaluate? method would return false,
    # since [entrylist] is an ancestor.
    def evaluate?
      sub = self
      ret = true
      while sub = sub.parent
        next unless Sub === sub
        if template.shielded_commands.include?(sub.name)
          ret = false
          break
        end
      end
      ret
    end
    
    # Returns the raw representation of the sub converted to a string.
    def raw_sub
      @raw_tokens.to_s
    end
    
    # If this sub replaced a sub in the node tree one frame back in the node tree
    # timeline, then that sub is the "insertion parent" of this sub. For example,
    # this is how the node tree might look after a variable is replaced:
    #
    #  Template1("[foo]")
    #    Parser1("[foo]")
    #      Document1
    #        Sub1("foo")              # 4. old_parent.template.parent.wrapper (or self.insertion_parent)
    #          Variable(foo="[bar]")  # 3. old_parent.template.parent
    #            Template2("[bar]")   # 2. old_parent.template
    #              Parser2("[bar]")   #
    #                Document2        # 1. old_parent
    #                  Sub2("bar")    # 0. self
    #  
    def insertion_parent
      @insertion_parent ||= (old_parent && old_parent.template.parent.wrapper)
    end
    
    # If this sub replaced a sub in some past timeline of the node tree (it could
    # have been one frame back or ten frames back), and if the sub that was replaced
    # has the same name and arguments as this sub, then that sub is the "insertion
    # doppelganger" of this sub. For example, this is what the node tree might look
    # like if a variable is replaced with a sub that contains the same variable
    # in its args:
    #
    #  Template1("[foo]")
    #    Parser1("[foo]")
    #      Document1
    #        Sub1("foo")                                               # 5. self.parent.parent.parent.parent.insertion_parent (or self.insertion_doppelganger)
    #          Variable1(foo="[frobulate [frobulate [foo] baz] bar]")   
    #            Template2("[frobulate [frobulate [foo] baz] bar]")
    #              Parser2("[frobulate [frobulate [foo] baz] bar]")
    #                Document2
    #                  Sub2("frobulate")                                 # 4. self.parent.parent.parent.parent
    #                    NodeList1                                       # 3. self.parent.parent.parent
    #                      Sub3("frobulate")                             # 2. self.parent.parent
    #                        NodeList2                                   # 1. self.parent
    #                          Sub4("foo")                               # 0. self
    def insertion_doppelganger
      @insertion_doppelganger ||= begin
        node = self
        dop = nil
        i = 0
        until dop or node.nil?
          dop = insertion_doppelganger_from(node)
          j = 0
          if dop.nil?
            # Hmm, I guess that didn't work. We might be inside an argument list,
            # so try climbing up the node tree until we hit a sub, and then search from there
            begin; node = node.parent; end until node.nil? or node.kind_of?(Sub)
            j += 1
            raise "Infinite loop" if j == 100
          end
          i += 1
          raise "Infinite loop" if i == 100
        end
        dop
      end
    end
    
    # for testing
    def ==(other)
      other.is_a?(self.class) &&
      @name == other.name &&
      @args == other.args &&
      @raw_tokens == other.raw_tokens
    end
  
    def pretty_print_instance_variables
      %w(@name @args)
    end
    
  protected
    def command_allowed?
      !self.template.allowed_commands || self.template.allowed_commands.include?(@name)
    end
    
    def evaluates_as_variable?
      if @args.empty?
        var = Variable.new(@name, @raw_tokens)
        var.parent = @parent
        var.wrapper = self
        @result = var.evaluate
        return true
      end
    rescue ParserError => e
      #Papyrus.debug("#{e.class}: #{e.message}")
      #Papyrus.debug(e.backtrace.join("\n"))
      return false
    end
    
    def insertion_doppelganger_from(node)
      # Go back through the insertion parents until we find a sub that has
      # the same name and args as this sub
      # But ensure that it is not the same object lest an infinite loop occurs
      dop = node
      begin
        dop = dop.insertion_parent
        dop = nil if dop.equal?(self)
      end until dop.nil? or dop == self
      dop
    end
  
  end
end