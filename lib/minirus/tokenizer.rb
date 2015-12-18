module Minirus
  class Tokenizer
    def initialize(content, grammar)
      @content = StringScanner.new(content.to_s)
      @grammar = grammar || {}
      check_grammar
    end

    def tokenize
      tokens = [ ]
      until @content.eos?
        @last_token = nil
        @grammar.each do |type, rule|
          @last_token = @content.scan(rule)
          if !@last_token.nil?
            tokens << Token.create(type, @last_token)
            break
          end
        end

        if @last_token.nil?
          @last_token = @content.get_byte
          if tokens.last.is_a?(Token::Text)
            tokens[-1] += @last_token
          else
            tokens << Token::Text.new(@last_token)
          end
        end
      end

      tokens
    end

  private
    def check_grammar
      @grammar.keys.each do |rule|
        raise UndefinedGrammarTypeError, "#{rule} is not a defined grammar" unless Token::const_defined?(rule.to_s.classify)
      end
    end
  end
end
