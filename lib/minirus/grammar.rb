module Minirus
  class Grammar
    include Enumerable

    delegate :[], :[]=, :keys, :to => :@rules

    def initialize
      @rules = {}
    end

    def each
      @rules.each { |r| yield r }
    end

    def method_missing(rule, *args)
      @rules[rule] = args.first if !args.empty?
      @rules[rule]
    end
  end
end
