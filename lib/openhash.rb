# Adapted from Ruby Facets
class OpenHash < HashWithIndifferentAccess
  undef_method :id
  
  def initialize(hash = {})
    super()
    update(hash)
  end
  
  def self.[](hash = {})
    new(hash)
  end
  
  # Route get and set calls.
  def method_missing(name, *args)
    name = name.to_s
    # do nothing if missing method
    return if name == 'default' && !args.empty?
    k = name.sub(/[?!=]$/, '')
    if name =~ /=$/
      self[k] = args.first
    elsif args.empty?
      self[k]
    else
      # this should never be called?!
      super(name, *args)
    end
  end
  
  def dup
    self.class.new(self)
  end
  
  def with_indifferent_access
    self
  end
  
## Uhm this method iz knot riten vry goodly?!  
## /home/codexed/rails/lib/codexed/openhash.rb:30:in `[]=': failed to allocate memory (NoMemoryError)
## FUN TIMES !!!!!!!!! N STUF
=begin
  InspectSeen = :__inspect_key__
  InspectLevel = :__inspect_level__

  def inspect
    Thread.current[InspectSeen] ||= {}
    Thread.current[InspectSeen][self.object_id] = (v = Thread.current[InspectSeen][self.object_id]) ? v+1 : 1
    Thread.current[InspectLevel] = (v = Thread.current[InspectLevel]) ? v+1 : 1
    str = "#<#{self.class}:#{self.object_id}"
    if Thread.current[InspectSeen][self.object_id] > 1
      str << " ..."
    else
      first = true
      each do |k, v|
        str << "," unless first
        first = false
        str << " #{k}=#{v.inspect}"
      end
    end
    str << ">"
    Thread.current[InspectSeen] = {} if Thread.current[InspectLevel] == 1
    Thread.current[InspectLevel] -= 1
    str
  end
=end

end

class Hash
  def to_openhash
    hash = self.dup
    hash.each {|k,v| hash[k] = v.to_openhash if v.is_a?(Hash) }
    OpenHash.new(hash)
  end
end

# Monkey-patch Rails' Array#extract_options! so that openhashes do not get included
class Array
  def extract_options!
    (last.is_a?(::Hash) && !last.is_a?(::OpenHash)) ? pop : {}
  end
end

#oh = OpenHash.new
#oh.x = 'y'
#oh.few = 3
#oh.regz = :sym
#oh['slimey'] = 'frog'
#puts "oh.inspect = " + oh.inspect
#puts "oh.few = #{oh.few}"
#puts "oh.slimey = #{oh.slimey}"
#exit

#openhash = OpenHash.new(
#  :foo => OpenHash.new(
#    :one => 'awexome',
#    :two => 'cross',
#    :three => 'homestar runner'
#  ),
#  :bar => OpenHash.new(
#    :michael => 'jackson',
#    :citizen => 'kane',
#    :bread => 'crumbs'
#  )
#)
#puts openhash.foo.inspect
#openhash.foo.one = 'pretty'
#puts openhash.foo.inspect
#exit

#hash = {:y=>{:z=>"foo"}, :x=>"blah"}
#puts hash.to_openhash.inspect
#exit