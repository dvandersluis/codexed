module Papyrus
  # The Parser is responsible for taking the TokenList created by the Tokenizer
  # and forming an abstract syntax tree (or AST) of nodes (which represent the
  # different types of text in the template string to be evaluated). In Papyrus, the
  # AST goes by the name of "Document".
  # 
  # Parsers are really only used internally -- you shouldn't have to create one
  # yourself unless you're doing something specific.
  class Parser
    attr_accessor :template, :document
    attr_reader :open_subs
    
    delegate :options, :to => :@template
    
    # Creates a new Parser, storing the template this Parser belongs to.
    def initialize(template)
      @template = template
      @document = Document.new(self)
      # The stack is used to keep track of open block commands. As a block command is
      # encountered, it's added to the stack. Nodes created while the command is open
      # are then added to its node list. When the command closes, it's then popped off
      # the stack.
      @stack = [ @document ]
      @open_subs = []
    end
    
    def tokens
      @template.tokenizer.tokens
    end
    
    # Advances through the token list and analyzes it to build a Document of nodes
    # (or, in the parlance of parsing, an abstract syntax tree).
    # Possible nodes are:
    #
    # * CustomBlockCommand
    # * InlineSub
    # * Text
    #
    def parse
      build_document
      close_open_block_commands
      @document
    end
    
    #def pretty_print_instance_variables
    #  ["@content"]
    #end
    
  private
    def build_document
      @head = tokens
      while token = tokens.advance
        if TokenList === token
          sub = build_sub
          (sub.kind_of?(BlockCommand) ? @stack : @stack.last) << sub if sub
        else
          @stack.last << Text.new(token)
        end
      end
    end
    
    # If any BlockCommands weren't closed properly, we just end them manually.
    def close_open_block_commands
      return unless @stack.size > 1
      until @stack.size == 1
        sub = @stack.pop
        @stack.last << sub
      end
    end
  
    def build_sub
      head = @head
      # descend into the TokenList
      raw_tokens = @head = @head.curr
      
      @head.advance  # left bracket
      
      if Token::Slash === @head.next
        handle_command_close
      else
        name, args = gather_sub_name_and_args
        ##return Text.new("") if modify_active_cmd(name, args)
        method_args = [ name, args, raw_tokens ]
        if @template.custom_commands && @template.custom_commands.class.has_block_command?(name)
          sub = CustomBlockCommand.new(*method_args)
        else
          sub = InlineSub.new(*method_args)
        end
        sub.parent = @stack.last
        sub
      end
    rescue ParserError => e
      # oops, had a problem gathering the sub name/args
      Text.new(raw_tokens.to_s)
    ensure
      # ascend out of the TokenList again
      @head = head
    end
    
    # Assuming we've already hit a left bracket and slash, pops off the command on
    # top of the stack if it looks like that command is being closed.
    #
    # An InvalidEndOfCommandError is raised if we hit the end of the token list
    # and the open command is never closed.
    #
    # An UnmatchedLeftBracketError is raised if we hit the end of the token list
    # before reaching a right bracket. 
    def handle_command_close
      @head.advance # slash
      command_name = @head.advance
      active_cmd = @stack.last
      
      raise InvalidCloseSubError   unless Token::Text === command_name
      raise UnmatchedCloseSubError unless BlockCommand === active_cmd && active_cmd.name == command_name
      
      cmd = @stack.pop
      @stack.last << cmd
      # get the rest of the command
      reached_eoc = false
      while token = @head.advance
        if Token::RightBracket === token
          reached_eoc = true
          break
        end
      end
      raise UnmatchedLeftBracketError unless reached_eoc
      
      return nil
    end
    
    ## If the given name doesn't refer to a command but just modifies the command
    ## on top of the stack (assuming it's a BlockCommand), returns true, otherwise
    ## returns false.
    #def modify_active_cmd(name, args)
    #  active_cmd = stack.last
    #  (active_cmd.is_a?(BlockCommand) && active_cmd.modified_by?(name, args)) || false
    #end
    
    # Assuming that we've already hit a left bracket, steps through the following
    # tokens to collect the name and arguments of the sub. Arguments enclosed in quotes
    # will be properly grouped together in a NodeList.
    #
    # Raises an UnmatchedSingleQuote or UnmatchedDoubleQuoteError if we've hit an
    # opening quote mark and we hit the end of the token list before reaching a
    # closing quote mark.
    #
    # Raises an UnmatchedLeftBracketError if we hit the end of the token list before
    # reaching a right bracket.
    def gather_sub_name_and_args
      name, args = nil, NodeList.new
      error = nil
      reached_eoc = false
      
      while token = @head.advance
        arg = nil
        case token
          when TokenList
            arg = build_sub
          when Token::RightBracket
            reached_eoc = true
            break
          when Token::SingleQuote, Token::DoubleQuote
            begin
              arg = build_arg
            rescue UnmatchedSingleQuoteError, UnmatchedDoubleQuoteError => error
              # keep going until we reach the end of the sub or the token list
            rescue MisplacedQuoteError
              arg = Text.new(token)
            end
          when Token::Whitespace
            # skip whitespace
          else
            arg = Text.new(token)
        end

        if arg
          if name
            args << arg
          else
            name = arg.evaluate.to_s
            @open_subs << name
          end
        end
      end
      
      raise error if error
      raise UnmatchedLeftBracketError unless reached_eoc
      raise UnknownSubError if name.nil?
      raise UnknownSubError if name.blank? || name !~ /^([a-z]+:)?[A-Za-z][\w.-]*$/
      
      [name, args]
    ensure
      @open_subs.pop if name
    end
    
    # Assuming that we've already hit an opening quote mark inside a sub, steps
    # through the following tokens to collect the tokens before the closing quote
    # mark that represent an argument inside that sub. The argument is wrapped in
    # a NodeList. If we encounter another sub within the argument, the corresponding
    # Sub object will be added to the NodeList.
    #
    # Raises a MisplacedQuoteError if the token before the opening quote character
    # is not a whitespace token.
    #
    # Raises an UnmatchedSingleQuoteError or UnmatchedDoubleQuoteError if we hit
    # the end of the token list before reaching a closing quote mark.
    def build_arg
      quote_klass = @head.curr.class
      arg = NodeList.new
      arg.parent = @stack.last
      ## Push a dummy BlockCommand onto the stack in case the top of the stack is a
      ## BlockCommand and we come across, say, 'else' in the middle of the string -
      ## we don't want that interpreted as a modifier
      #@stack << NodeList.new(@stack.last)
      
      raise MisplacedQuoteError unless Token::Whitespace === @head.prev or Token::LeftBracket === @head.prev
      
      reached_eoq = false
      unmatched_error = (quote_klass == Token::SingleQuote) ? UnmatchedSingleQuoteError : UnmatchedDoubleQuoteError
      while token = @head.advance
        case token
        when quote_klass
          reached_eoq = true
          break
        when TokenList
          arg << build_sub
        when Token::RightBracket
          break
        else
          arg << Text.new(token)
        end
      end
      raise unmatched_error unless reached_eoq
      arg
    #ensure
    #  # we can take the dummy value off now
    #  @stack.pop
    end
    
  end
end
