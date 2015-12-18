module Papyrus
  # The Tokenizer is responsible for splitting and categorizing the content of the
  # source template into lexemes or tokens, which are the smallest strings of
  # characters that are significant to the Papyrus grammar. Once we have the content
  # categorized, we can then loop through and interpret it later.
  #
  # Tokenizers are really only used internally -- you shouldn't have to create one
  # yourself unless you're doing something specific.
  class Tokenizer
    attr_reader :template, :tokens
    
    delegate :content, :to => :@template
    
    # Creates a new Tokenizer, storing the Parser this Tokenizer belongs to.
    def initialize(template)
      @template = template
    end
    
    # Steps through the content and splits it into an array of tokens. Possible tokens are:
    #
    # * Token::LeftBracket
    # * Token::RightBracket
    # * Token::SingleQuote
    # * Token::DoubleQuote
    # * Token::Slash
    # * Token::Whitespace
    # * Token::Text
    #
    # Here's what ends up happening:
    #
    # * Quotes, brackets, and forward slashes are represented by their own tokens
    #   and those tokens are pushed individually onto the token list.
    # * Words and anything else that's not a quote, bracket or slash character are
    #   grouped together in a Token::Text.
    # * If a left or right bracket is preceded by a backslash, then we use a Token::Text
    #   to represent the bracket instead of a Token::LeftBracket or Token::RightBracket,
    #   so that the sub isn't interpreted.
    # * The set of tokens that represent a sub is always wrapped in a TokenList so we
    #   can easily detect it later.
    #
    # At the end of the tokenization, @tokens will hold the token list.
    #
    # NOTE: There's a tiny bit of magic going on when we actually go to add the token
    # to the token list. See TokenList#add for what's up.
    def tokenize
      @stack = [ TokenList.new ]
      @num_open_brackets = 0
      @token_buffer = nil
      until content.eos?
        if @num_open_brackets > 0
          build_token_list_inside_sub
        else
          build_token_list_outside_sub
        end
      end
      flush_token_buffer
      flush_stack
      
      @tokens = @stack.first
    end
    
  private
    ## TODO: Store regexes in constants for further optimization
  
    def build_token_list_inside_sub
      if str = content.scan(/\]/)
        flush_token_buffer
        @stack.last << Token::RightBracket.new
        tokens = @stack.pop
        @stack.last << tokens
        @num_open_brackets -= 1
      elsif @token_buffer.blank? && Token::LeftBracket === @stack.last.last and str = content.scan(/(\s*)(\/)/)
        flush_token_buffer
        @stack.last << Token::Whitespace.new(content[1]) unless content[1].blank?
        @stack.last << Token::Slash.new
      elsif str = content.scan(/\s+/)
        flush_token_buffer
        @stack.last << Token::Whitespace.new(str)
      elsif content.scan(/"/)
        flush_token_buffer
        @stack.last << Token::DoubleQuote.new
      elsif content.scan(/'/)
        flush_token_buffer
        @stack.last << Token::SingleQuote.new
      elsif content.scan(/\[/)
        @num_open_brackets += 1
        flush_token_buffer
        @stack << TokenList[ Token::LeftBracket.new ]
      else
        # This could probably be DRYed up
        @token_buffer ||= Token::Text.new
        if str = content.scan(/\\/)
          if str2 = content.scan(/\[|\]/)
            @token_buffer << str2
          else
            @token_buffer << str
          end
        end
        if str = content.scan(/[^\s"'\[\]\\]+/)
          @token_buffer << str
        end
      end
    end
    
    def build_token_list_outside_sub
      if content.scan(/\[/)
        @num_open_brackets += 1
        flush_token_buffer
        @stack << TokenList[ Token::LeftBracket.new ]
      elsif str = content.scan(/\\/)
        # This could probably be DRYed up
        @token_buffer ||= Token::Text.new
        if str2 = content.scan(/\[|\]/)
          @token_buffer << str2
        else
          @token_buffer << str
          if str2 = content.scan(/[^\[]+/)
            @token_buffer << str2
          end
        end
      elsif str = content.scan(/[^\\\[]+/)
        (@token_buffer ||= Token::Text.new) << str
      end
    end
    
    def flush_token_buffer
      if @token_buffer
        @stack.last << Token::Text.new(@token_buffer)
        @token_buffer = nil
      end
    end
    
    def flush_stack
      return if @stack.size == 1
      # A left bracket might have been left open so sweep any remaining items on the
      # stack together and stick 'em on the end of the first item
      stray_tokens = @stack.slice!(1..-1)
      @stack.first << stray_tokens.flatten.join
    end
    
  end
end