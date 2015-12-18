module SpecifyTests
  def self.included(klass)
    klass.extend(ClassMethods)
  end
  module ClassMethods
=begin
  def only_do(*methods)
    methods.map!(&:to_s)
    #methods = public_instance_methods - methods.map(&:to_s)
    #ignore(*methods)
    methods_to_only_do.merge(methods)
    overwrite_run_method_if_necessary
  end
  def ignore(*methods)
    methods.map!(&:to_s)
    #methods = methods.map(&:to_s).select {|m| method_defined?(m.to_sym) && m =~ /^test_/ }
    methods_to_ignore.merge(methods)
    overwrite_run_method_if_necessary
  end
  def methods_to_ignore
    @methods_to_ignore ||= Set.new
  end
  def methods_to_only_do
    @methods_to_only_do ||= Set.new
  end
  def methods_to_delete
    (Set.new(public_instance_methods) - methods_to_only_do) + methods_to_ignore
  end
#private
  def overwrite_run_method_if_necessary
    return unless @_already_overwrote_run
    class_eval do
      alias_method :orig_run, :run
      def run(result)
        raise "self is: #{self}"
        unless self.class.methods_to_delete.include?(@method_name.to_s)
          orig_run(result) {|args| yield(*args) }
        end
      end
    end
    @_already_overwrote_run = true
  end
=end
    def only_do(*methods)
      methods = public_instance_methods - methods.map(&:to_s)
      ignore(*methods)
    end
    def ignore(*methods)
      methods = methods.map(&:to_s).select {|m| method_defined?(m.to_sym) && m =~ /^test_/ }
      methods.each {|m| undef_method(m.to_sym) }
    end
  end
end
