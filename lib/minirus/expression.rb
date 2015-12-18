module Minirus
  # Allows for pure Ruby expressions within template code
  class Expression
    attr_accessor :variables, :methods
    def initialize(variables = VariableList.new, method_class = Methods)
      @variables = variables
      @methods = method_class.is_a?(Class) ? method_class.new : const_get(method_class).new
      @methods.instance_variable_set("@variables", @variables)
    end

    def parse(method, args)
      method = :expr if method.nil?
      raise InvalidExpressionMethodError, "#{method} is not a defined Expression method" unless @methods.method_exists? method
      @methods.send(method, args)
    end

    class Methods
      # Format: [expr]:var expression
      # Evaluates an expression using a variable
      def expr(args)
        var, *rest = args.split(" ")
        instance_variable_set("@v", @variables[var].to_s)
        return eval(rest.join(" ")).to_s.strip
      end

      # Format: ifset:var1[:var2:var3:...] if_true [, if_false]
      # If only one variable is being checked, it can be used in if_true by referring to @v
      # If multiple variables are being checked, it is an AND check
      # Multiple variables can be referred to by @a for the first, @b for the second, etc.
      # A maximum of 26 variables can be used
      def ifset(args)
        var, *rest = args.split(" ")
        if_true, if_false = rest.join(" ").split(",")

        raise ArgumentError, "A variable name must be given for ifset Expression Method" if var.nil? or var.blank?
        raise ArgumentError, "if_true must be given for ifset Expression Method" if if_true.nil? or if_true.blank?

        if (vars = var.split(":")).length > 1
          raise ArgumentError, "Too many variables given for ifset Expression Method" if vars.length > 26
          vars.map!{ |v| @variables[v] }
          set = vars.all? { |v| !(v.nil? or v.blank?) }
        else
          var = @variables[var]
          set = !(var.nil? or var.blank?)
        end
        
        if set
          if vars.size > 1
            vars.each_with_index do |v, i|
              instance_variable_set("@#{('a'.ord + i).chr}", v)
            end
          else
            instance_variable_set("@v", var)
          end

          return eval(if_true).to_s.strip
        else
          if_false = eval(if_false) unless if_false.nil?
          return if_false.to_s.strip
        end
      end

      # Format: foreach:var expression
      # If a var is an Enumerable, allows an expression to be evaluated for each value
      def foreach(args)
        var, *rest = args.split(" ")
        vars = @variables[var]
        rest = rest.join(" ")
        vars = [vars] if !vars.is_a? Enumerable

        vars.inject([]) do |memo, v|
          v = v.last if v.is_a? Array
          instance_variable_set("@v", v)
          memo << eval(rest)
        end.join
      end
    end
  end
end
