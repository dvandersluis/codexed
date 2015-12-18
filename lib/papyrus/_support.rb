# This file is only here so we can require it during tests

require 'pp'
require 'strscan'

class Symbol
  def to_proc
    Proc.new{|*args| args.shift.__send__(self, *args)}
  end
end

class String
  def camelize(first_letter_in_uppercase = true)
    if first_letter_in_uppercase
      self.to_s.gsub(/\/(.?)/) { "::#{$1.upcase}" }.gsub(/(?:^|_)(.)/) { $1.upcase }
    else
      self.first + self.camelize[1..-1]
    end
  end
end

class Object
  module InstanceExecMethods; end
  include InstanceExecMethods
  
  # Copied from Rails
  def blank?
    (respond_to?(:empty?) && empty?) || nil?
  end
  # Copied from Rails
  def returning(value)
    yield(value)
    value
  end
  def deep_copy
    Marshal.load(Marshal.dump(self))
  end
  def instance_exec(*args, &block)
    begin
      old_critical, Thread.critical = Thread.critical, true
      n = 0
      n += 1 while respond_to?(method_name = "__instance_exec#{n}")
      InstanceExecMethods.module_eval { define_method(method_name, &block) }
    ensure
      Thread.critical = old_critical
    end
  
    begin
      send(method_name, *args)
    ensure
      InstanceExecMethods.module_eval { remove_method(method_name) } rescue nil
    end
  end
end

module Enumerable
  def inject_with_index(injected)
    each_with_index {|obj, index| injected = yield(injected, obj, index) }
    injected
  end
end

class Array
  def extract_options!
    last.is_a?(::Hash) ? pop : {}
  end
end

class Hash
  def symbolize_keys
    inject({}) {|hash,(k,v)| hash[k.to_sym] = v; hash }
  end
  def symbolize_keys!
    replace(symbolize_keys)
  end
  def stringify_keys
    inject({}) {|hash,(k,v)| hash[k.to_s] = v; hash }
  end
  def stringify_keys!
    replace(stringify_keys)
  end
  def deep_merge(second)
    # Since Configuration objects have a Hash member named vars, allow Hash.deep_merge(Configuration)
    if defined?(Configuration)
      if second.is_a? Configuration and !second.vars.nil?
        second = second.vars
      end
    end
    merger = proc do |k,v1,v2|
      if v1.is_a?(Hash) && v2.is_a?(Hash)
        v1.merge(v2, &merger)
      else
        v2
      end
    end
    self.merge(second, &merger)
  end
  def deep_merge!(second)
    replace(deep_merge(second))
  end
end

class File
  def self.read(file)
    File.open(file) {|f| f.read }
  end
  def self.write(file, content)
    File.open(file, "w") {|f| f.write(content) }
  end
end

# Copied from Rails, provides a more readable alternative to Ruby's Forwardable module
class Module
  def delegate(*methods)
    options = methods.pop
    unless options.is_a?(Hash) && to = options[:to]
      raise ArgumentError, "Delegation needs a target. Supply an options hash with a :to key as the last argument (e.g. delegate :hello, :to => :greeter)."
    end

    if options[:prefix] == true && options[:to].to_s =~ /^[^a-z_]/
      raise ArgumentError, "Can only automatically set the delegation prefix when delegating to a method."
    end

    prefix = options[:prefix] && "#{options[:prefix] == true ? to : options[:prefix]}_"

    allow_nil = options[:allow_nil] && "#{to} && "

    methods.each do |method|
      module_eval(<<-EOS, "(__DELEGATION__)", 1)
        def #{prefix}#{method}(*args, &block)                           # def customer_name(*args, &block)
          #{allow_nil}#{to}.__send__(#{method.inspect}, *args, &block)  #   client && client.__send__(:name, *args, &block)
        end                                                             # end
      EOS
    end
  end
end

# Copied from ActiveSupport
class Class
  def cattr_reader(*syms)
    syms.flatten.each do |sym|
      next if sym.is_a?(Hash)
      class_eval(<<-EOS, __FILE__, __LINE__)
        unless defined? @@#{sym}  # unless defined? @@hair_colors
          @@#{sym} = nil          #   @@hair_colors = nil
        end                       # end
                                  #
        def self.#{sym}           # def self.hair_colors
          @@#{sym}                #   @@hair_colors
        end                       # end
                                  #
        def #{sym}                # def hair_colors
          @@#{sym}                #   @@hair_colors
        end                       # end
      EOS
    end
  end

  def cattr_writer(*syms)
    options = syms.extract_options!
    syms.flatten.each do |sym|
      class_eval(<<-EOS, __FILE__, __LINE__)
        unless defined? @@#{sym}                       # unless defined? @@hair_colors
          @@#{sym} = nil                               #   @@hair_colors = nil
        end                                            # end
                                                       #
        def self.#{sym}=(obj)                          # def self.hair_colors=(obj)
          @@#{sym} = obj                               #   @@hair_colors = obj
        end                                            # end
                                                       #
        #{"                                            #
        def #{sym}=(obj)                               # def hair_colors=(obj)
          @@#{sym} = obj                               #   @@hair_colors = obj
        end                                            # end
        " unless options[:instance_writer] == false }  # # instance writer above is generated unless options[:instance_writer] == false
      EOS
    end
  end

  def cattr_accessor(*syms)
    cattr_reader(*syms)
    cattr_writer(*syms)
  end
end