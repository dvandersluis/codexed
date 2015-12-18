require File.dirname(__FILE__)+'/test_helper'

describe Papyrus::InlineSub do

  before do
    @is = InlineSub.new("", NodeList.new, [])
  end
  
  describe '#evaluate' do
    before :each do
      @is.stub_method(:evaluates_as_inline_command_or_variable? => true)
      @is.ivs "@result", "some result"
    end
    it "should evaluate @args and store the resulting array in @evaluated_args" do
      args = NodeList.new
      args.stub_methods(:to_a => %w(foo bar))
      @is.ivs "@args", args
      @is.evaluate
      @is.ivg("@evaluated_args").should == %w(foo bar)
    end
    it "should make a copy of @args before it's evaluated" do
      args = NodeList.new([ Text.new("foo") ])
      @is.ivs "@args", args
      @is.evaluate
      @is.ivg("@orig_args").should == args
    end
    describe "if the sub could be evaluated" do
      it "should update the raw tokens with the result of the evaluation" do
        @is.evaluate
        @is.ivg("@raw_tokens").should == TokenList[ Token::Text.new("some result") ]
      end
      it "should return the result of the evaluation" do
        @is.ivs "@result", "some result"
        @is.evaluate.should == "some result"
      end
    end
    describe "should return the raw sub" do
      it "if the inline sub shouldn't be evaluated" do
        @is.stub_methods(:evaluate? => false, :raw_sub => "[foo]")
        @is.evaluate.should == "[foo]"
      end
      it "if the inline sub can't be evaluated" do
        @is.stub_methods(:evaluate? => true, :evaluates_as_inline_command_or_variable? => false, :raw_sub => "[foo]")
        @is.evaluate.should == "[foo]"
      end
    end
  end
  
  #---
  
  describe '#evaluates_as_inline_command_or_variable?' do
    before :each do
      @is.stub_methods(
        :evaluates_as_builtin_command? => false,
        :evaluates_as_custom_inline_command? => false,
        :evaluates_as_variable? => false
      )
    end
    it "should return true if we can evaluate the sub as a built-in command" do
      @is.stub_methods(:evaluates_as_builtin_command? => true)
      @is.send(:evaluates_as_inline_command_or_variable?).should == true
    end
    it "should return true if we can evaluate the sub as a custom command" do
      @is.stub_methods(:evaluates_as_custom_inline_command? => true)
      @is.send(:evaluates_as_inline_command_or_variable?).should == true
    end
    it "should return true if we can evaluate the sub as a variable" do
      @is.stub_methods(:evaluates_as_variable? => true)
      @is.send(:evaluates_as_inline_command_or_variable?).should == true
    end
  end
  
  describe '#evaluates_as_builtin_command?' do
    it "should return true if the command is allowed and the command is in the lexicon" do
      @is.stub_methods(:command_allowed? => true)
      klass = Class.new(Sub) { def evaluate; ""; end }
      Papyrus::Lexicon.stub_methods(:commands => { "foo" => klass })
      @is.ivs "@name", "foo"
      @is.ivs "@orig_args", NodeList.new
      @is.send(:evaluates_as_builtin_command?).should == true
    end
    it "should return false if the command is not allowed" do
      @is.stub_methods(:command_allowed? => false)
      @is.send(:evaluates_as_builtin_command?).should == false
    end
    it "should return false if the command is allowed, but the command is not in the lexicon" do
      @is.stub_methods(:command_allowed? => true)
      Papyrus::Lexicon.stub_methods(:commands => {})
      @is.send(:evaluates_as_builtin_command?).should == false
    end
    it "should return nil if a ParserError is raised while the command is evaluated" do
      @is.stub_methods(:command_allowed? => true)
      klass = Class.new(Sub) { def evaluate; raise ParserError; end }
      Papyrus::Lexicon.stub_methods(:commands => { "foo" => klass })
      @is.ivs "@name", "foo"
      @is.ivs "@orig_args", NodeList.new
      @is.send(:evaluates_as_builtin_command?).should == false
    end
    # how do we add tests for setting parent and wrapper?
  end
  
  describe '#evaluates_as_custom_inline_command?' do
    describe "if the command is allowed and a custom command set was given" do
      before do
        @is.ivs(
          "@name" => "foo", 
          "@orig_args" => NodeList.new(%w(foo bar baz).map {|x| Text.new(x) }),
          "@evaluated_args" => %w(foo bar baz)
        )
        @custom_commands = stub(:__call_inline_command__ => "the final string")
        @is.stub_methods(:command_allowed? => true, :template => stub(:custom_commands => @custom_commands))
        @result = @is.send(:evaluates_as_custom_inline_command?)
      end
      it "should call the custom command" do
        @custom_commands.should have_received(:__call_inline_command__).with(@is)
      end
      it "should store the result of the custom command" do
        @is.ivg("@result").should == "the final string"
      end
      it "should return true" do
        @result.should == true
      end
    end
    describe "should return false" do
      it "if the command is not allowed" do
        @is.stub_methods(:command_allowed? => false)
      end
      it "if the command is allowed, but no custom command set has been given" do
        @is.stub_methods(:command_allowed? => true, :template => stub(:custom_commands => nil))
      end
      it "if a ParserError is raised while the command is evaluated" do
        custom_commands = Object.new
        custom_commands.stub_methods_to_raise(:__call_inline_command__ => ParserError)
        @is.stub_methods(:command_allowed? => true, :template => stub(:custom_commands => custom_commands))
      end
      after do
        @is.send(:evaluates_as_custom_inline_command?).should == false
      end
    end
  end

end