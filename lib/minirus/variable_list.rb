module Minirus
  class VariableList < Hash
    def initialize(hash = {})
      super()
      update(hash.symbolize_keys) if hash.is_a? Hash
    end

    def [](key)
      key = key.to_sym
      value = (if key.to_s =~ /\./
        keys = key.to_s.split(/\./)
        hash = self
        while key = keys.shift
          hash = hash[key]
          break if hash.nil?
        end
        hash
      else
        super(key)
      end)
      value = self.class.new(value.symbolize_keys) if value.is_a? Hash
      value
    end

    def []=(key, value)
      super(key.to_sym, value)
    end

    def method_missing(name, *args)
      k = name.to_s.sub(/[?!=]$/, '')
      if name.to_s =~ /=$/
        self[k] = args.first
      elsif args.empty?
        self[k]
      else
        super(name, *args)
      end
    end
  end
end
