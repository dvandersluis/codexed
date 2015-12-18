require File.dirname(__FILE__)+'/test_helper'

require 'tempfile'

class Template2 < Template
  def initialize(options={})
    @options = options
    # nothing else should happen
  end
end

describe Papyrus::Template do
  
  before :each do 
    @template = Template.new("")
  end

  describe '.new' do
    it 'should set @content to the given content' do
      # note that the lack of any_instance here makes it impossible to test that #content= was called
      Template.new("some content").ivg("@content").should == StringScanner.new("some content")
    end
    it "should set @options[:vars]/@vars to the given hash" do
      template = Template.new("", :vars => { "foo" => "bar" })
      template.ivg("@vars").should == { "foo" => "bar" }
      template.ivg("@options")[:vars].should == { "foo" => "bar" }
    end
    it "should set @options[:vars]/@vars to a hash by default" do
      template = Template.new("")
      template.ivg("@vars").should == {}
      template.ivg("@options")[:vars].should == {}
    end
    it "should set @options[:custom_commands]/@custom_commands to an instance of @options[:custom_command_class], if given" do
      template = Template.new("", :custom_command_class => CustomCommandSet)
      template.ivg("@options")[:custom_commands].should be_a(CustomCommandSet)
      template.ivg("@custom_commands").should be_a(CustomCommandSet)
    end
    it "should still set @options[:custom_commands]/@custom_commands if it is supplied, even if :custom_command_class is given" do
      template = Template.new("", :custom_commands => :something, :custom_command_class => CustomCommandSet)
      template.ivg("@options")[:custom_commands].should be_a(CustomCommandSet)
      template.ivg("@custom_commands").should be_a(CustomCommandSet)
    end
    it "should set @options[:custom_commands]/@custom_commands to nil if @options[:custom_command_class] is not given" do
      template = Template.new("")
      template.ivg("@options")[:custom_commands].should == nil
      template.ivg("@custom_commands").should == nil
    end
    it "should set @options[:shielded_commands]/@shielded_commands to an array by default" do
      template = Template.new("")
      template.ivg("@options")[:shielded_commands].should == []
      template.ivg("@shielded_commands").should == []
    end
    it "should set @options[:shielded_commands]/@shielded_commands to the given array" do
      template = Template.new("", :shielded_commands => %w(foo))
      template.ivg("@options")[:shielded_commands].should == %w(foo)
      template.ivg("@shielded_commands").should == %w(foo)
    end
    it "should set @options[:allowed_commands]/@allowed_commands to the given array" do
      template = Template.new("", :allowed_commands => %w(foo))
      template.ivg("@options")[:allowed_commands].should == %w(foo)
      template.ivg("@allowed_commands").should == %w(foo)
    end
  end
  
  describe '#dup or #clone (via #initialize_copy)' do
    it "should make a shallow copy of the original template's options" do
      template2 = @template.clone
      template2.options.should_not equal(@template.options)
    end
    it "should make a deep copy of the original template's variables" do
      template = Template.new("", :vars => { :foo => { :bar => "baz" } })
      template2 = template.clone
      template2.vars.should_not equal(template.vars)
      template2.options[:vars].should_not equal(template.options[:vars])
      template2.vars[:foo][:biz] = :niz
      template.vars[:foo][:biz].should_not == :niz
    end
    it "should make a shallow copy of the original template's custom command set" do
      template = Template.new("", :custom_command_class => CustomCommandSet)
      template2 = template.clone
      template2.custom_commands.should_not equal(template.custom_commands)
    end
    it "should make a shallow copy of the original template's shielded commands" do
      template2 = @template.clone
      template2.shielded_commands.should_not equal(@template.shielded_commands)
      template2.options[:shielded_commands].should_not equal(@template.options[:shielded_commands])
    end
    it "should make a shallow copy of the original template's allowed commands, if they are defined" do
      template = Template.new("", :allowed_commands => %w(foo bar))
      template2 = template.clone
      template2.allowed_commands.should_not equal(template.allowed_commands)
      template2.options[:allowed_commands].should_not equal(template.options[:allowed_commands])
    end
    it "should make a shallow copy of the original template's parser, if it has been defined" do
      template = Template.new("")
      template.ivs("@parser", Parser.new(nil))
      template2 = template.clone
      template2.parser.should_not equal(template.parser)
    end
    it "should set the template of the cloned parser to the cloned template" do
      template = Template.new("")
      template.ivs("@parser", Parser.new(nil))
      template2 = template.clone
      template2.parser.template.should equal(template2)
    end
  end
  
  describe '.render' do
    it "should replace subs in the given content and return the final content" do
      template = Template.new("")
      template.stub_methods(:render => "the rendered content")
      Template.stub_methods(:new => template)
      Template.render("the source content").should == "the rendered content"
    end
  end
  
  #---
  
  describe '#analyze' do
    it "should just call #tokenize and #parse" do
      @template.stub_methods(:tokenize => nil, :parse => nil)
      @template.analyze
      @template.should have_received(:tokenize)
      @template.should have_received(:parse)
    end
  end
  
  describe '#render' do
    before :each do
      @template.stub_methods(:analyze => nil, :evaluate => nil, :process_bodies => nil)
      @options = @template.ivg("@options")
      @options[:extra] = {}
      @template.ivs "@results", []
    end
    it 'should call #analyze' do
      @template.render
      @template.should have_received(:analyze)
    end
    it 'should call #evaluate' do
      @template.render
      @template.should have_received(:evaluate)
    end
    it 'should call #process_bodies if a callback was supplied to process the body' do
      @options[:extra][:process_body] = :block
      @template.render
      @template.should have_received(:process_bodies)
    end
    it 'should not call #process_bodies if options[:extra] is nil' do
      @options[:extra] = nil
      @template.render
      @template.should_not have_received(:process_bodies)
    end
    it 'should return the results joined as a string' do
      @template.stub_method(:evaluate) { @results = ["foobarbaz"] }
      @template.render.should == "foobarbaz"
    end
  end
  
  describe '#content=' do
    it "should store the given content straight if it is a StringScanner" do
      @template.content = StringScanner.new("this is not a sentence")
      @template.ivg("@content").should == StringScanner.new("this is not a sentence")
    end
    it "should convert the given string to a StringScanner before storing it, if it is not already a StringScanner" do
      @template.content = "this is not a sentence"
      @template.ivg("@content").should == StringScanner.new("this is not a sentence")
    end
    it "should reset the tokenizer and parser" do
      @template.analyze
      @template.content = "whatever"
      @template.ivg("@tokenizer").should be_nil
      @template.ivg("@parser").should be_nil
      @template.ivg("@results").should be_nil
    end
  end
  
  describe '#clone_with' do
    it "should return a clone of the Template, with its content set to the given content" do
      template = Template.new("the content")
      template2 = template.clone_with("some other content", {})
      template2.content.should == StringScanner.new("some other content")
    end
    it "should return a clone of the Template, but with the given options merged into the pre-existing options" do
      template = Template.new("", { :foo => 'bar' })
      template2 = template.clone_with("", { :baz => 'quux' })
      template2.options.should contain(:foo => 'bar', :baz => 'quux')
    end
    it "the given options should be deep-merged into pre-existing options" do
      template = Template.new("", :foo => {:bar => 'baz'})
      template2 = template.clone_with("", :foo => {:baz => 'quux'})
      template2.options[:foo].should == {:bar => 'baz', :baz => 'quux'}
    end
    it "options should be, well, optional" do
      template = Template.new("", :foo => {:bar => 'baz'})
      template2 = template.clone_with("")
      template2.options[:foo].should == {:bar => 'baz'}
    end
  end
  
  describe '#template' do
    it "should return itself" do
      @template.template.should == @template
    end
  end
  
  #---
  
  describe '#tokenize' do
    it "should create a new Tokenizer, run the content through it and return the generated token list" do
      # poor man's any_instance :(
      Tokenizer.stub_methods :new => (returning Tokenizer.new(@template) do |x|
        x.stub_methods(:tokenize => :token_list)
      end)
      @template.send(:tokenize).should == :token_list
    end
  end
  
  describe '#parse' do
    it "should create a new Parser, run the given token list through it and return the generated Document" do
      @template.ivs("@tokenizer", stub(:tokens => nil))
      # poor man's any_instance :(
      Parser.stub_methods :new => (returning Parser.new(@template) do |x|
        x.stub_methods(:parse => :document)
      end)
      @template.send(:parse).should == :document
    end
  end
  
  describe '#evaluate' do
    it "should evaluate each node in the document and store an array (not a string) of results" do
      @template.ivs "@parser", stub("document.evaluate" => ["the results"])
      @template.send(:evaluate)
      @template.ivg("@results").should == ["the results"]
    end
  end
  
  describe '#process_bodies' do
    it "should run through BodyStrings found in the evaluation results and process them, if the Document has any BodyStrings and the process_body callback was supplied to the Template" do
      callback = lambda { 'processed body' }
      @template.ivg("@options")[:extra] = { :process_body => callback }
      @template.ivs "@results", ['text', BodyString.new('body'), 'text' ]
      @template.send :process_bodies
      @template.ivg("@results").should == ['text', 'processed body', 'text']
    end
    it "should do nothing to the evaluation results if the Document does not have any BodyStrings" do
      callback = lambda { 'processed body' }
      @template.ivg("@options")[:extra] = { :process_body => callback }
      @template.ivs "@results", ['text', 'text', 'text' ]
      @template.send :process_bodies
      @template.ivg("@results").should == ['text', 'text', 'text']
    end
  end
  
end