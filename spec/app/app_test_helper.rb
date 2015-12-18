require File.dirname(__FILE__) + '/../global_test_helper'

#raise $LOAD_PATH.inspect

# We need a way of testing whether or not certain Rails classes have been defined.
# The defined? operator would work, except you have to pass it the class name, and the second
# Rails sees the class name (even if it's being passed to defined?), it will try to load it.
# So this is simply a mechanism to get around that.
#def const_exists?(const)
#  objects = []
#  [Module, Class].each do |type|
#    ObjectSpace.each_object(type) {|x| objects << x.to_s }
#  end
#  objects.include?(const)
#end

require 'active_support'
Dependencies.load_paths = $LOAD_PATH

Dir["#{RAILS_ROOT}/config/initializers/aaa_extensions/ruby/**/*.rb"].each {|file| require File.expand_path(file) }