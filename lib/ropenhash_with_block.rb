require File.dirname(__FILE__) + '/ropenhash'

# ROpenHashWithBlock is a recursive OpenHash, but it comes with a couple of features:
#   - You can pass a block to an attribute, which ultimately lets you access an
#     attribute at some point in the hierarchy in an other attribute lower
#     in the hierarchy
#   - You can use a Proc as an attribute value, which lets you defer the real value
#     of that attribute until the moment the attribute is accessed later
#
class ROpenHashWithBlock < ROpenHash
  attr_reader :parent
  
  def initialize(*args)
    hash = args.last.is_a?(::Hash) ? args.pop : {}
    @parent = args.first || self
    super()
    update(hash)
  end
  
  def method_missing(name, *args)
    name = name.to_s
    if name =~ /=$/
      super
    else
      v = super
      k = name.gsub(/[?!=]$/, '')
      returning self[k] do |v|
        yield(v) if block_given?  # really only useful if val is a OpenHash
      end
    end
  end
  
  alias_method :regular_reader, :[]
  # if value is a Proc, call it, passing the parent hash and
  #  returning its return value, otherwise return value as usual
  def [](name)
    v = regular_reader(name)
    v.is_a?(Proc) ? v.call(@parent) : v
  end
end

#test = ROpenStructWithBlock.new
#test.x = 'blah'
#test.y.z = 'foo'
#test.z do |z|
#  z.r do |r|
#    r.b = 'x'
#    r.y = Proc.new { z.r }
#  end
#end

#puts test.inspect
#exit