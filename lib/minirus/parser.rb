module Minirus
  class Parser
    def initialize(content = nil, variables = nil, &blk)
      @content = content
      @variables = VariableList.new(variables)
      @grammar = Grammar.new
      blk.call(@grammar) if block_given?
      self
    end

    def parse
      tokens.map do |t|
        if t.is_a? Minirus::Token::Comment
          ""
        elsif t.is_a? Minirus::Token::Variable
          process_var(t)
        elsif t.is_a? Minirus::Token::Expression
          process_expr(t)
        else
          t 
        end
      end.join
    end

  private
    def tokens
      tokenizer = Tokenizer.new(@content, @grammar)
      tokenizer.tokenize
    end

    def process_var(token)
      variable_name = @grammar.variable.match(token)[1]
      defined?(@variables[variable_name]) ? @variables[variable_name].to_s : token
    end

    def process_expr(token)
      method, expr = @grammar.expression.match(token)[1,2]
      Expression.new(@variables).parse(method, expr)
    end
  end
end

