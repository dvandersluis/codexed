module Minirus
  module Token
    class Base < ::String
      def +(other)
        replace(super(other.to_s))
      end
    end

    class Comment < Base
      def initialize(str = nil)
        super(str.to_s)
      end
    end

    class Expression < Base
      def initialize(str = nil)
        super(str.to_s)
      end
    end

    class Variable < Base
      def initialize(str = nil)
        super(str.to_s) 
      end
    end

    class Text < Base
      def initialize(str = nil)
        super(str.to_s)
      end
    end
  
    def self.create(type, text)
      klass = Token.const_get(type.to_s.classify.to_sym)
      klass.new(text)
    end
  end
end

