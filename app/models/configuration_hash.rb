class ConfigurationHash < OpenHash
  
  # Undefining #default and #default= lets us use "default" as an option category,
  # however, it causes a "no id given" exception if you try to refer to a nonexistent
  # key (i.e. if you say "config.foo" and config.foo is undefined).
  # The workaround is to say "config.foo if config.include? :foo"
  undef_method :default  if method_defined? :default
  undef_method :default= if method_defined? :default=
  
  def [](k)
    super(k.to_s)
  end

  # When a value is stored, implicitly convert it to a number or a boolean value,
  # or leave it alone, depending on what it is and how it looks.
  def []=(k, v)
    v = type_cast(v)
    super(k, v)
  end
  
  def dup
    self.class.new(self)
  end
  
  def to_hash
    # recursively convert values to hashes
    inject({}) {|memo,(k,v)| memo[k] = v.is_a?(Hash) ? v.to_hash : v; memo }
  end
  
private
  # XXX: This is called every time a hash item is accessed or written to. Is this bad??
  def type_cast(value)
    if value.is_a? Array
      value = value.map {|v| type_cast(v) }
    elsif value.is_a?(Hash)
      # recursively type cast
      value = value.inject(self.class.new) {|memo,(k,v)| memo[k] = v; memo }
      #value = value.to_config_hash
    elsif value.is_a? String
      value = nil         if value == '' || value == 'nil'
      value = true        if value == 'true'
      value = false       if value == 'false'
      value = value.to_f  if value =~ /^(\+|-)?\d+\.\d+?$/
      value = value.to_i  if value =~ /^(\+|-)?\d+$/
    end
    value
  end
  
end

class Hash
  def to_config_hash
    ConfigurationHash.new(self)
  end
end
