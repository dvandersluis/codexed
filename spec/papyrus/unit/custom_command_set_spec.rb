require File.dirname(__FILE__)+'/test_helper'

describe Papyrus::CustomCommandSet do
  
  before do
    @klass = Class.new(CustomCommandSet)
    @klass::InlineCommands = Module.new
    @klass::BlockCommands = Module.new

    @klass.send(:include, @klass::InlineCommands)
    @klass.send(:include, @klass::BlockCommands)
  end
  
  describe '.command_properties' do
    it "should assign @command_properties a new hash if it's not defined yet" do
      @klass.command_properties
      @klass.ivg("@command_properties").should == {}
    end
    it "should set the default value of the hash to a hash" do
      @klass.command_properties["foo"]["bar"] = "baz"
      @klass.ivg("@command_properties")["foo"]["bar"].should == "baz"
    end
    it "should return the value of @command_properties if it's already defined" do
      @klass.ivs("@command_properties", { :foo => "bar" })
      @klass.command_properties.should == { :foo => "bar" }
    end
  end
  
  describe '.aliases' do
    it "should assign @aliases a new hash if it's not defined yet" do
      @klass.aliases
      @klass.ivg("@aliases").should == {}
    end
    it "should return the value of @aliases if it's already defined" do
      @klass.ivs("@aliases", { :foo => "bar" })
      @klass.aliases.should == { :foo => "bar" }
    end
  end
  
  describe '.alias_command' do
    it "should store the name of the real command under the name of the alias" do
      @klass.alias_command "jimmy", "fallon"
      @klass.ivg("@aliases")["fallon"].should == "jimmy"
    end
    it "should ensure the alias is stored lowercase" do
      @klass.alias_command "jiMmY", "fallon"
      @klass.ivg("@aliases")["fallon"].should == "jimmy"
    end
    it "should ensure the alias is stored as a string" do
      @klass.alias_command :jimmy, "fallon"
      @klass.ivg("@aliases")["fallon"].should == "jimmy"
    end
    it "should ensure the real command is stored lowercase" do
      @klass.alias_command "jimmy", "fAllOn"
      @klass.ivg("@aliases")["fallon"].should == "jimmy"
    end
    it "should ensure the real command is stored as a string" do
      @klass.alias_command "jimmy", :fallon
      @klass.ivg("@aliases")["fallon"].should == "jimmy"
    end
  end

  describe '.has_inline_command?' do
    before do
      @klass::InlineCommands.module_eval do
        def bugger; end
      end

      @klass.class_eval do |klass|
        alias_command :bugger, :zap
      end
    end
    
    it "should return true if InlineCommands has a command" do
      @klass.has_inline_command?("bugger").should == true
    end

    it "should return true if InlineCommands has a command that is aliased" do
      @klass.has_inline_command?("zap").should == true
    end

    it "should return false if InlineCommands does not have a command" do
      @klass.has_inline_command?("slapstick").should == false
    end
  end
  
  describe '.has_block_command?' do
    before do
      @klass::BlockCommands.module_eval do
        def bugger; end
      end

      @klass.class_eval do |klass|
        alias_command :bugger, :zap
      end
    end

    it "should return true if BlockCommands has a command" do
      @klass.has_block_command?("bugger").should == true
    end
    it "should return true if BlockCommands has a command that is aliased" do
      @klass.has_block_command?("zap").should == true
    end
    it "should return false if BlockCommands does not have a command" do
      @klass.has_block_command?("slapstick").should == false
    end
  end
end

describe Papyrus::CustomCommandSet do
  
  describe '.new' do
    it "should set @template to the given template" do
      set = CustomCommandSet.new(:template, [])
      set.ivg("@template").should == :template
    end
    it "should set @args to the given args" do
      set = CustomCommandSet.new(nil, %w(foo bar))
      set.ivg("@args").should == %w(foo bar)
    end
  end
  
  describe '#dup and #clone (via #initialize_copy)' do
    it "should make a shallow copy of the args" do
      set = CustomCommandSet.new(:template, { :foo => "bar" })
      set2 = set.clone
      set2.args[:baz] = "quux"
      set.args[:baz].should be_nil
    end
  end
  
  describe '#__call_inline_command__' do
    before :each do
      module CustomCommandSet::InlineCommands
        def foo(args)
          [args, :return_value]
        end

        def bar(args)
          [args, :return_value]
        end
      end

      CustomCommandSet.class_eval do
        dont_pre_evaluate_args :bar
      end
      CustomCommandSet.send(:include, CustomCommandSet::InlineCommands)

      @set = CustomCommandSet.new(nil, [])
    end
    it "should call the given inline command with the arrayified arguments, if the command is defined" do
      sub = stub(:name => "foo", :evaluated_args => %w(foo bar))
      value = @set.send(:__call_inline_command__, sub)
      value.should == [%w(foo bar), :return_value]
    end
    it "should call the given inline command with the original argument NodeList, if the command was defined dont_pre_evaluate_args" do
      sub = stub(:name => "bar", :orig_args => NodeList.new([ Text.new("foo") ]))
      value = @set.send(:__call_inline_command__, sub)
      value.should == [ NodeList.new([ Text.new("foo") ]), :return_value ]
    end
    it 'should call #inline_command_missing if the inline command is not defined' do
      @set.stub_methods(:inline_command_missing => nil)
      sub = stub(:name => "baz", :evaluated_args => %w(foo bar))
      @set.send(:__call_inline_command__, sub)
      @set.should have_received(:inline_command_missing).with("baz", %w(foo bar))
    end
  end
  
  describe '#__call_block_command__' do
    before :each do
      module CustomCommandSet::BlockCommands
        def foo(args, inner)
          [args, inner, :return_value]
        end

        def bar(args, inner)
          [args, inner, :return_value]
        end
      end

      CustomCommandSet.class_eval do
        dont_pre_evaluate_args :bar
      end
      CustomCommandSet.send(:include, CustomCommandSet::BlockCommands)

      @set = CustomCommandSet.new(nil, [])
    end
    it "should call the given block command with the arrayified arguments, if the command is defined" do
      sub = stub(:name => "foo", :evaluated_args => %w(foo bar), :evaluated_nodes => "quuxblargh")
      value = @set.send(:__call_block_command__, sub)
      value.should == [%w(foo bar), "quuxblargh", :return_value]
    end
    it "should call the given block command with the original argument NodeList, if the command was defined with :pre_evaluate_args => false" do
      sub = stub(:name => "bar", :orig_args => NodeList.new([ Text.new("foo") ]), :evaluated_nodes => "quuxblargh")
      value = @set.send(:__call_block_command__, sub)
      value.should == [ NodeList.new([ Text.new("foo") ]), "quuxblargh", :return_value ]
    end
    it 'should call #block_command_missing if the block command is not defined' do
      @set.stub_methods(:block_command_missing => nil)
      sub = stub(:name => "baz", :evaluated_args => %w(foo bar), :evaluated_nodes => "quuxblargh")
      @set.send(:__call_block_command__, sub)
      @set.should have_received(:block_command_missing).with("baz", %w(foo bar), "quuxblargh")
    end
  end
  
  #---
  
  describe '#inline_command_missing' do
    it "should raise an UnknownSubError by default" do
      lambda { CustomCommandSet.new(nil, []).send(:inline_command_missing, "", []) }.should raise_error(UnknownSubError)
    end
  end
  
  describe '#block_command_missing' do
    it "should raise an UnknownSubError by default" do
      lambda { CustomCommandSet.new(nil, []).send(:block_command_missing, "", [], []) }.should raise_error(UnknownSubError)
    end
  end
  
end
