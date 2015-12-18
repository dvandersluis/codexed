module Papyrus
  # A Token is used in the parsing process to better distinguish special characters
  # in the template being parsed and thus make it possible to interpret the template procedurally.
  module Token
    class Base < ::String
      def ==(other)
        self.class == other.class && self.to_s == other.to_s
      end
      def to_s
        String.new(self)
      end
      def inspect
        "#<#{self.class}: #{super}>"
      end
    end
    class DoubleQuote < Base
      def initialize(str='"')
        super(str)
      end
    end
    class SingleQuote < Base
      def initialize(str="'")
        super(str)
      end
    end
    class LeftBracket < Base
      def initialize(str="[")
        super(str)
      end
    end
    class RightBracket < Base
      def initialize(str="]")
        super(str)
      end
    end
    class Slash < Base
      def initialize(str="/")
        super(str)
      end
    end
    class Whitespace < Base
      def initialize(str=" ")
        super(str)
      end
    end
    class Text < Base
      def initialize(str=nil)
        super(str.to_s)
      end
    end

  
    # Returns a new Token based on the given token type and text.
    def self.create(type, text)
      klass = Token.const_get(type.to_s.classify.to_sym)
      klass.new(text)
    end
  end
end
