RAILS_ROOT = File.expand_path(File.dirname(__FILE__) + "/../")

ENV['RAILS_ENV'] = RAILS_ENV = 'test'

load_paths = [RAILS_ROOT, "#{RAILS_ROOT}/lib"]
Dir["#{RAILS_ROOT}/vendor/{gems,plugins}/**"].map do |dir| 
  load_paths << (File.directory?(lib = "#{dir}/lib") ? lib : dir)
end
Dir["#{RAILS_ROOT}/vendor/rails/**"].each do |framework|
  load_paths << "#{framework}/lib"
end
$LOAD_PATH.unshift(*load_paths.reverse)

#---

require "rubygems"
require "spec"

# We have to do this because NotAMock doesn't require every file explicitly for whatever reason
Dir["#{RAILS_ROOT}/vendor/plugins/not_a_mock/lib/**/*.rb"].each {|file| require file }

Spec::Runner.configure do |config|
  config.mock_with NotAMock::RspecMockFrameworkAdapter
end

# Custom RSpec matchers
(class << Spec::Example::ExampleGroup; self; end).class_eval do
  def it_should_delegate(*methods, &block)
    # ex: node.template -> node.parent.template
    options = methods.extract_options!
    raise ":to option must be defined" unless options[:to]
    origin = options[:from].is_a?(Proc) ? options[:from].call : options[:from]
    method_args = Array(options[:with])
    target_id = options[:to].to_s
    for method in methods
      method = method.to_sym
      nice_method = "#{origin.is_a?(Class) ? '.' : '#'}#{method}"
      describe nice_method do
        it "should be delegated to #{target_id}" do
          origin = options[:from].is_a?(Proc) ? options[:from].call : options[:from]
          target = nil
          case target_id
            # node's template delegates to node's @@parent's template
            when /^@@/ then target = origin.send(:class_variable_get, target_id)
            # node's template delegates to node's @parent's template
            when /^@/  then target = origin.send(:instance_variable_get, target_id)
            # node's template delegates to node's parent's template, so stub+track node.parent call
            else            target = Object.new; origin.stub_methods(target_id.to_sym => target)
          end
          # stub node.parent.template
          target.stub_methods(method => nil)
          if method_args[-1].is_a?(Proc)
            proc = method_args.pop
            # send node.template with the args and proc
            origin.send(method, *method_args, &proc)
          else
            # send node.template with the args
            origin.send(method, *method_args)
          end
          # ensure node.parent.template was called
          target.should have_received(method)
        end
        if options[:allow_nil]
          it "should not be delegated to #{target_id} if the #{origin.class.to_s.split('::').last.downcase} is nil" do
            origin = options[:from].is_a?(Proc) ? options[:from].call : options[:from]
            target = nil
            case target_id
              # node's template delegates to node's @@parent's template but @@parent is nil
              when /^@@/ then origin.send(:class_variable_set, target_id, nil)
              # node's template delegates to node's @parent's template but @parent is nil
              when /^@/  then origin.send(:instance_variable_set, target_id, nil)
              # node's template delegates to node's parent's template, but node.parent is nil
              else            origin.stub_methods(target_id.to_sym => nil)
            end
            ret = origin.send(method)
            target.should_not have_received(method)
            ret.should == nil
          end
        end
      end
    end
  end
end

class Object
  # convenience method
  def stub(methods)
    stub = Object.new
    stub.stub_methods(methods)
    stub
  end
  # patch not_a_mock so we can stub methods recursively
  # so instead of doing this:
  #
  #  stub(:foo => stub(:bar => stub(:baz => :quux)))
  #
  # You can simply write:
  #
  #  stub("foo.bar.baz" => :quux)
  #
  def stub_method(method, &block)
    case method
      when String, Symbol
        method = method.to_s
        # x.stub_method("foo.bar.baz") { "quux" }
        if method.include?(".")
          # "foo", "bar.baz"
          first, rest = method.split(".", 2)
          #begin
          #  # try x.foo
          #  obj = send(first)
          #rescue NoMethodError
            # stub x.foo
            obj = Object.new
            stub_methods(first => obj)
          #end
          # x.foo.stub_method("bar.baz") { "quux" }
          obj.stub_method(rest, &block)
        else
          method = method.to_sym
          NotAMock::CallRecorder.instance.untrack_method(self, method)
          NotAMock::Stubber.instance.unstub_method(self, method)
          NotAMock::Stubber.instance.stub_method(self, method, &block)
          NotAMock::CallRecorder.instance.track_method(self, method)
        end
      when Hash
        stub_methods(method)
      else
        raise ArgumentError
    end
  end
end

module Enumerable
  def contain?(other)
    self.class === other && other.all? {|x| include?(x) }
  end
end

class Hash
  def contain?(other)
    self.class === other && other.all? {|k,v| self[k] == v }
  end
end

Spec::Matchers.define :contain do |other|
  match do |enum|
    enum.respond_to?(:contain?) && enum.contain?(other)
  end
  failure_message_for_should do |enum|
    "expected #{enum.inspect} to contain #{other.inspect}, but it didn't"
  end
  failure_message_for_should_not do |enum|
    "expected #{enum.inspect} to not contain #{other.inspect}, but it did"
  end
  description do
    "should contain #{other.inspect}"
  end
end

#---

class Object
  alias_method :ivg, :instance_variable_get
  public :ivg
  def ivs(name_or_hash, value=nil)
    if name_or_hash.is_a?(Hash)
      name_or_hash.each {|name, value| instance_variable_set(name, value) }
    else
      instance_variable_set(name_or_hash, value)
    end
  end
end

class Module
  alias_method :cvg, :class_variable_get
  public :cvg
  def cvs(name_or_hash, value=nil)
    if name_or_hash.is_a?(Hash)
      name_or_hash.each {|name, value| class_variable_set(name, value) }
    else
      class_variable_set(name_or_hash, value)
    end
  end
end