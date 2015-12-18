unless defined?(OpenHash)
  require RAILS_ROOT / 'lib' / 'openhash'
end

# This is a recursive OpenHash, which means it allows you to generate a
# pseudo-attribute-based hierarchy on the fly. So, for example:
#
#  test = ROpenHash.new
#  test.p = "hello"
#  test.t.s.p.t.z.y.x = "hi"
#  test.xyz
#
# Credit goes to "benny" <listen@marcrenearns.de> for the inspiration
# See <http://blade.nagaokaut.ac.jp/cgi-bin/scat.rb/ruby/ruby-talk/150311>
#
# With modifications by Elliot Winkler
#
class ROpenHash < OpenHash  
  def method_missing(name, *args)
    name = name.to_s
    k = name.gsub(/[?!=]$/, '')
    if name =~ /=$/
      # set value
      self[k] = args.first
    else
      unless include?(k)
        # user is attempting to access an attribute, so create
        # another recursive OpenHash on the fly
        v = self.class.new
        self[k] = v
      end
      self[k]
    end
  end
  
  def deep_clone
    each_pair do |k,v|
      if v.respond_to?(:deep_clone)
        v = v.deep_clone
      else
        v = v.dup rescue v
      end
      self[k] = v
    end
    dup
  end
end

#test = ROpenHash.new
#test.x = 'blah'
#test.y.z = 2
#test.z.m.u = :sym

#puts "test = #{test.inspect}"
#puts "test.x = #{test.x.inspect}"
#puts "test.y = #{test.y.inspect}"
#puts "test.z.m = #{test.z.m.inspect}"
#puts "test.z.m.u = #{test.z.m.u.inspect}"
#exit

#puts test.inspect
#puts test.dup.inspect
#puts test.deep_clone.inspect
#exit