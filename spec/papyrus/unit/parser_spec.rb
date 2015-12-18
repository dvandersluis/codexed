require File.dirname(__FILE__)+'/test_helper'

class SomeBlockCommand < BlockCommand
end

describe Papyrus::Parser do
  
  before :each do
    @parser = Parser.new(nil)
  end
  
  it_should_delegate :options, :to => :@template, :from => Parser.new(nil)
  
  describe '.new' do
    it "should set @template to the given template" do
      Parser.new(:template).ivg("@template").should == :template
    end
    it "should initialize the Document" do
      @parser.ivg("@document").should be_a(Document)
    end
    it "should initialize the stack" do
      @parser.ivg("@stack").first.should == @parser.ivg("@document")
    end
  end
  
  #describe '#dup and #clone (via #initialize_copy)' do
  #  it "should make a copy of the Document" do
  #    parser2 = @parser.clone
  #    parser2.document.should_not equal(@parser.document)
  #  end
  #end
  
  #describe '#document=' do
  #  it "should set the given document's parser to this parser" do
  #    @parser.document = Document.new(nil)
  #    @parser.document.parser.should == @parser
  #  end
  #end
  
  describe '#tokens' do
    it "should be delegated to @template.tokenizer" do
      tokenizer = stub(:tokens => nil)
      @parser.ivs("@template", stub(:tokenizer => tokenizer))
      @parser.tokens
      tokenizer.should have_received(:tokens)
    end
  end
  
  describe '#parse' do
    it "should return the resulting Document" do
      @parser.stub_methods(:build_document => nil, :close_open_block_commands => nil)
      @parser.parse.should be_a(Document)
    end
  end
  
  #---
  
  describe '#build_document' do
    before :each do 
      @parser.stub_methods :tokens => TokenList.new
    end
    it "should reset @open_subs" do
      @parser.send :build_document
      @parser.ivg("@open_subs").should == []
    end
    it "should set @head to tokens" do
      @parser.send :build_document
      @parser.ivg("@head").should == @parser.tokens
    end
    it 'should call #build_sub and add the resulting Sub to the Document upon hitting a sub-TokenList' do
      @parser.stub_methods :tokens => TokenList[ TokenList.new ]
      sub = Sub.new("", NodeList.new, [])
      @parser.stub_methods(:build_sub => sub)
      @parser.send :build_document
      @parser.should have_received(:build_sub)
      @parser.ivg("@document").last.should == sub
    end
    it 'should not add anything to the Document if #build_sub returns nothing' do
      @parser.stub_methods :tokens => TokenList[ TokenList.new ]
      @parser.stub_methods(:build_sub => nil)
      lambda { @parser.send :build_document }.should_not change(@parser.ivg("@document"), :size)
    end
    it 'should add everything else to the Document as just text' do
      @parser.stub_methods :tokens => TokenList[ Token::Text.new("foo") ]
      @parser.send :build_document
      @parser.ivg("@document").last.should == Text.new("foo")
    end
  end
  
  describe '#close_open_block_commands' do
    it "should automatically close block commands that are still open at the end of the parsing process" do
      @parser.stub_methods :tokens => TokenList.new
      stack = @parser.ivg("@stack")
      cmd = SomeBlockCommand.new("", NodeList.new, [])
      stack << cmd
      @parser.send(:close_open_block_commands)
      stack.size.should == 1
      stack[0].nodes[0].should == cmd
    end
  end
  
  describe '#build_sub' do
    it "should delegate to #handle_command_close if the next token is a slash" do
      @parser.ivs "@head", stub(:curr => stub(:advance => nil, :next => Token::Slash.new))
      @parser.stub_methods(:handle_command_close => nil)
      @parser.send(:build_sub)
      @parser.should have_received(:handle_command_close)
    end
    #it "should return a Text node containing the raw sub if the parent sub is shielded" do
    #  name, args = "bar", NodeList.new([ Text.new("baz") ])
    #  @parser.stub_methods(:gather_sub_name_and_args => [name, args])
    #  raw_tokens = stub(:advance => nil, :next => nil, :to_s => "[bar]")
    #  @parser.ivs(
    #    "@head" => stub(:curr => raw_tokens),
    #    "@open_subs" => %w(foo),
    #    "@options" => { :shielded_commands => %w(foo) }
    #  )
    #  @parser.send(:build_sub).should == Text.new("[bar]")
    #end
    describe "when a custom command set was supplied and it recognizes this sub as a block command" do
      before do
        @name, @args = "bar", NodeList.new([ Text.new("baz") ])
        @parser.stub_methods(:gather_sub_name_and_args => [@name, @args])
        @raw_tokens = TokenList[ "whatever" ]; @raw_tokens.stub_methods(:next => nil)
        @parser.ivs(
          "@head" => stub(:curr => @raw_tokens),
          "@open_subs" => [],
          "@template" => stub("custom_commands.class.has_block_command?" => true)
        )
      end
      it "should return a CustomBlockCommand" do
        @parser.send(:build_sub).should == CustomBlockCommand.new(@name, @args, @raw_tokens)
      end
      it "should go ahead and assign a parent to the new sub in case it's being used as the name of an outer sub" do
        @parser.ivs "@stack", [ :outer_sub ]
        @parser.send(:build_sub).parent.should == :outer_sub
      end
    end
    describe "when it does not recognize this sub as a block command" do
      before do
        @name, @args = "bar", NodeList.new([ Text.new("baz") ])
        @parser.stub_methods(:gather_sub_name_and_args => [@name, @args])
        @raw_tokens = TokenList[ "whatever" ]; @raw_tokens.stub_methods(:next => nil)
        @parser.ivs(
          "@head" => stub(:curr => @raw_tokens),
          "@open_subs" => [],
          "@template" => stub(:custom_commands => nil)
        )
      end
      it "should return an InlineSub" do
        @parser.send(:build_sub).should == InlineSub.new(@name, @args, @raw_tokens)
      end
      it "should go ahead and assign a parent to the new sub in case it's being used as the name of an outer sub" do
        @parser.ivs "@stack", [ :outer_sub ]
        @parser.send(:build_sub).parent.should == :outer_sub
      end
    end
    it "should return a Text node containing the raw sub if gather_sub_name_and_args raises a ParserError" do
      @parser.stub_methods_to_raise(:gather_sub_name_and_args => ParserError)
      raw_tokens = Object.stub_instance(:advance => nil, :next => nil, :to_s => "[bar]")
      @parser.ivs "@head", stub(:curr => raw_tokens)
      @parser.send(:build_sub).should == Text.new("[bar]")
    end
  end
  
  describe '#handle_command_close' do
    it "should raise an InvalidCloseSubError if the command name is not a Text token" do
      @parser.ivs "@head", TokenList[ Token::Slash.new, Token::RightBracket.new ]
      lambda { @parser.send(:handle_command_close) }.should raise_error(InvalidCloseSubError)
    end
    it "should raise an UnmatchedCloseSubError if the command name is a Text token, but the active command is not a BlockCommand" do
      @parser.ivs(
        "@head" => TokenList[ Token::Slash.new, Token::Text.new ],
        "@stack" => [ Document.new(nil) ]
      )
      lambda { @parser.send(:handle_command_close) }.should raise_error(UnmatchedCloseSubError)
    end
    it "should raise an UnmatchedCloseSubError if the command name is a Text, active command is a BlockCommand, but this sub does not close the active command" do
      @parser.ivs(
        "@head" => TokenList[ Token::Slash.new, Token::Text.new("foo") ],
        "@stack" => [ SomeBlockCommand.new("bar", NodeList.new, []) ]
      )
      lambda { @parser.send(:handle_command_close) }.should raise_error(UnmatchedCloseSubError)
    end
    describe "handling command close" do
      before do
        @document = []
        @cmd = SomeBlockCommand.new("foo", NodeList.new, [])
        @stack = [ @document, @cmd ]
        @parser.ivs(
          "@head" => TokenList[ Token::Slash.new, Token::Text.new("foo"), Token::RightBracket.new ],
          "@stack" => @stack
        )
      end
      it "should pop the block command off the stack" do
        @parser.send(:handle_command_close)
        @stack.should == [ @document ]
      end
      it "should append the block command to the node before" do
        @parser.send(:handle_command_close)
        @document.should == [ @cmd ]
      end
      it "should return nil" do
        @parser.send(:handle_command_close).should == nil
      end
    end
    it "should raise an UnmatchedLeftBracketError if the closing sub was not closed with a right bracket" do
      @parser.ivs(
        "@head" => TokenList[ Token::Slash.new, Token::Text.new("foo") ],
        "@stack" => [ [], SomeBlockCommand.new("foo", NodeList.new, []) ]
      )
      lambda { @parser.send(:handle_command_close) }.should raise_error(UnmatchedLeftBracketError)
    end
  end
  
  describe '#gather_sub_name_and_args' do
    before :each do
      @parser.stub_methods(:build_arg => nil, :build_sub => nil)
      @parser.ivs "@open_subs", []
    end
    it "should successfully extract the name and arguments from a sub" do
      @parser.ivs "@head", TokenList[
        Token::Text.new("foo"),
        Token::Whitespace.new(" "),
        Token::Text.new("bar"),
        Token::Whitespace.new(" "),
        Token::Text.new("baz"),
        Token::RightBracket.new
      ]
      @parser.send(:gather_sub_name_and_args).should == [
        'foo',
        NodeList.new([ Text.new('bar'), Text.new('baz') ])
      ]
    end
    it "should call #build_arg when a single-quoted argument is reached" do
      @parser.ivs "@head", TokenList[
        Token::Text.new("foo"),
        Token::SingleQuote.new,
        Token::Text.new("bar"),
        Token::SingleQuote.new,
        Token::RightBracket.new
      ]
      @parser.send(:gather_sub_name_and_args)
      @parser.should have_received(:build_arg).twice
    end
    it "should call #build_arg when a double-quoted argument is reached" do
      @parser.ivs "@head", TokenList[
        Token::Text.new("foo"),
        Token::DoubleQuote.new,
        Token::Text.new("bar"),
        Token::DoubleQuote.new,
        Token::RightBracket.new
      ]
      @parser.send(:gather_sub_name_and_args)
      @parser.should have_received(:build_arg).twice
    end
    it "should raise an UnmatchedLeftBracketError if the end of the token list is reached before the command ends" do
      @parser.ivs "@head", TokenList[
        Token::Text.new("foo"),
        Token::Whitespace.new(" "),
        Token::Text.new("bar")
      ]
      lambda { @parser.send(:gather_sub_name_and_args) }.should raise_error(UnmatchedLeftBracketError)
    end
    it "should rescue and re-raise an UnmatchedSingleQuoteError if a single quote is left unmatched before the command ends" do
      @parser.ivs "@head", TokenList[
        Token::Text.new("foo"),
        Token::Whitespace.new(" "),
        Token::SingleQuote.new,
        Token::Text.new("bar"),
        Token::RightBracket.new
      ]
      @parser.stub_methods_to_raise(:build_arg => UnmatchedSingleQuoteError)
      lambda { @parser.send(:gather_sub_name_and_args) }.should raise_error(UnmatchedSingleQuoteError)
    end
    it "should rescue and re-raise an UnmatchedDoubleQuoteError if a double quote is left unmatched before the command ends" do
      @parser.ivs "@head", TokenList[
        Token::Text.new("foo"),
        Token::Whitespace.new(" "),
        Token::DoubleQuote.new,
        Token::Text.new("bar"),
        Token::RightBracket.new
      ]
      @parser.stub_methods_to_raise(:build_arg => UnmatchedDoubleQuoteError)
      lambda { @parser.send(:gather_sub_name_and_args) }.should raise_error(UnmatchedDoubleQuoteError)
    end
    it "should call build_sub when an inner sub (more specifically, a sub-TokenList) is reached" do
      @parser.ivs "@head", TokenList[
        Token::Text.new("foo"),
        Token::Whitespace.new,
        Token::Text.new("bar"),
        Token::Whitespace.new,
        TokenList.new,
        Token::RightBracket.new
      ]
      @parser.send(:gather_sub_name_and_args)
      @parser.should have_received(:build_sub)
    end
    it "should raise an UnknownCommandError if the sub name is blank" do
      tokens = TokenList[
        Token::SingleQuote.new,
        Token::SingleQuote.new,
        Token::RightBracket.new
      ]
      @parser.ivs "@head", tokens
      lambda { @parser.send(:gather_sub_name_and_args) }.should raise_error(UnknownSubError)
    end
    it "should raise an UnknownCommandError if the sub name is not a valid identifier" do
      tokens = TokenList[
        Token::Text.new(".foo"),
        Token::RightBracket.new
      ]
      @parser.ivs "@head", tokens
      lambda { @parser.send(:gather_sub_name_and_args) }.should raise_error(UnknownSubError)
    end
    it "should raise an UnknownCommandError if the sub is empty" do
      tokens = TokenList[
        Token::RightBracket.new
      ]
      @parser.ivs "@head", tokens
      lambda { @parser.send(:gather_sub_name_and_args) }.should raise_error(UnknownSubError)
    end
    it "should add to list of open commands while sub name and args are gathered" do
      open_subs = []
      open_subs.track_methods(:<<)
      tokens = TokenList[
        Token::Text.new("foo"),
        Token::RightBracket.new
      ]
      @parser.ivs "@head" => tokens, "@open_subs" => open_subs
      @parser.send(:gather_sub_name_and_args)
      # can't just test that "foo" is in open commands since it's popped afterwards
      open_subs.should have_received(:<<).with("foo")
    end
    it "should pop off the open command after the sub has been parsed" do
      open_subs = []
      open_subs.track_methods(:pop)
      tokens = TokenList[
        Token::Text.new("foo"),
        Token::RightBracket.new
      ]
      @parser.ivs "@head" => tokens, "@open_subs" => open_subs
      @parser.send(:gather_sub_name_and_args)
      # can't just test that "foo" is in open commands since it's popped afterwards
      open_subs.should have_received(:pop)
    end
  end
  
  describe '#build_arg' do
    before :each do
      @parser.ivs "@open_subs", []
    end
    it "should return the contents of a single-quoted argument in a NodeList" do
      tokens = TokenList[
        Token::LeftBracket.new,
        Token::Text.new("foo"),
        Token::Whitespace.new(" "),
        Token::SingleQuote.new,
        Token::Text.new("bar"),
        Token::SingleQuote.new,
        Token::RightBracket.new
      ]
      tokens.ivs "@pos", 3
      @parser.ivs "@head", tokens
      @parser.send(:build_arg)
    end
    it "should return the contents of a double-quoted argument in a NodeList" do
      tokens = TokenList[
        Token::LeftBracket.new,
        Token::Text.new("foo"),
        Token::Whitespace.new(" "),
        Token::DoubleQuote.new("'"),
        Token::Text.new("bar"),
        Token::DoubleQuote.new("'"),
        Token::RightBracket.new
      ]
      tokens.ivs "@pos", 3
      @parser.ivs "@head", tokens
      @parser.send(:build_arg)
    end
    it "should handle quoted arguments containing spaces correctly" do
      tokens = TokenList[
        Token::LeftBracket.new,
        Token::Text.new("foo"),
        Token::Whitespace.new(" "),
        Token::DoubleQuote.new,
        Token::Text.new("bar"),
        Token::Whitespace.new(" "),
        Token::Text.new("baz"),
        Token::Whitespace.new(" "),
        Token::Text.new("quux"),
        Token::DoubleQuote.new,
        Token::RightBracket.new
      ]
      tokens.ivs "@pos", 3
      @parser.ivs "@head", tokens
      @parser.send(:build_arg)
    end
    it "should raise an UnmatchedSingleQuoteError if a single quote is left unmatched before the sub ends" do
      tokens = TokenList[
        Token::LeftBracket.new,
        Token::Text.new("foo"),
        Token::Whitespace.new(" "),
        Token::SingleQuote.new,
        Token::Text.new("bar"),
        Token::RightBracket.new
      ]
      tokens.ivs "@pos", 3
      @parser.ivs "@head", tokens
      lambda { @parser.send(:build_arg) }.should raise_error(UnmatchedSingleQuoteError)
    end
    it "should raise an UnmatchedDoubleQuoteError if a double quote is left unmatched before the sub ends" do
      tokens = TokenList[
        Token::LeftBracket.new,
        Token::Text.new("foo"),
        Token::Whitespace.new(" "),
        Token::DoubleQuote.new("'"),
        Token::Text.new("bar"),
        Token::RightBracket.new
      ]
      tokens.ivs "@pos", 3
      @parser.ivs "@head", tokens
      lambda { @parser.send(:build_arg) }.should raise_error(UnmatchedDoubleQuoteError)
    end
    it "should raise an UnmatchedSingleQuoteError if a single quote is left unmatched before the end of the token list is reached" do
      tokens = TokenList[
        Token::LeftBracket.new,
        Token::Text.new("foo"),
        Token::Whitespace.new(" "),
        Token::SingleQuote.new,
      ]
      tokens.ivs "@pos", 3
      @parser.ivs "@head", tokens
      lambda { @parser.send(:build_arg) }.should raise_error(UnmatchedSingleQuoteError)
    end
    it "should raise an UnmatchedDoubleQuoteError if a double quote is left unmatched before the end of the token list is reached" do
      tokens = TokenList[
        Token::LeftBracket.new,
        Token::Text.new("foo"),
        Token::Whitespace.new(" "),
        Token::DoubleQuote.new("'"),
      ]
      tokens.ivs "@pos", 3
      @parser.ivs "@head", tokens
      lambda { @parser.send(:build_arg) }.should raise_error(UnmatchedDoubleQuoteError)
    end
    it "should call #handle_sub when a nested sub (or, more specifically, a sub-TokenList) is reached" do
      tokens = TokenList[
        Token::LeftBracket.new,
        Token::Text.new("foo"),
        Token::Whitespace.new(" "),
        Token::DoubleQuote.new,
        TokenList[
          Token::LeftBracket.new,
          Token::Text.new("bar"),
          Token::RightBracket.new
        ],
        Token::DoubleQuote.new,
        Token::RightBracket.new
      ]
      tokens.ivs "@pos", 3
      @parser.ivs "@head", tokens
      @parser.stub_methods(:build_sub => nil)
      begin; @parser.send(:build_arg); rescue UnmatchedDoubleQuoteError; end
      @parser.should have_received(:build_sub)
    end
    it "should raise a MisplacedQuoteError when the quote mark is not preceded by whitespace or a left bracket" do
      tokens = TokenList[
        Token::Text.new("bar"),
        Token::SingleQuote.new,
        Token::Text.new("baz"),
        Token::SingleQuote.new
      ]
      tokens.ivs "@pos", 1
      @parser.ivs "@head", tokens
      lambda { @parser.send(:build_arg) }.should raise_error(MisplacedQuoteError)
    end
    it "should not raise a MisplacedQuoteError if the quote mark is preceded by a left bracket" do
      tokens = TokenList[
        Token::LeftBracket.new,
        Token::SingleQuote.new,
        Token::Text.new("baz"),
        Token::SingleQuote.new
      ]
      tokens.ivs "@pos", 1
      @parser.ivs "@head", tokens
      lambda { @parser.send(:build_arg) }.should_not raise_error(MisplacedQuoteError)
    end
    it "should not raise a MisplacedQuoteError if the quote mark is preceded by whitespace" do
      tokens = TokenList[
        Token::Whitespace.new(" "),
        Token::SingleQuote.new,
        Token::Text.new("baz"),
        Token::SingleQuote.new
      ]
      tokens.ivs "@pos", 1
      @parser.ivs "@head", tokens
      lambda { @parser.send(:build_arg) }.should_not raise_error(MisplacedQuoteError)
    end
    it "should treat two quotes in a row as an empty argument" do
      tokens = TokenList[
        Token::LeftBracket.new,
        Token::SingleQuote.new,
        Token::SingleQuote.new
      ]
      tokens.ivs "@pos", 1
      @parser.ivs "@head", tokens
      nodes = @parser.send(:build_arg)
      nodes.should be_empty
    end
    it "should go ahead and assign a parent to the new NodeList" do
      tokens = TokenList[
        Token::LeftBracket.new,
        Token::Text.new("foo"),
        Token::Whitespace.new(" "),
        Token::SingleQuote.new,
        Token::Text.new("bar"),
        Token::SingleQuote.new,
        Token::RightBracket.new
      ]
      tokens.ivs "@pos", 3
      @parser.ivs "@head", tokens
      @parser.ivs "@stack", [ :outer_sub ]
      @parser.send(:build_arg).parent.should == :outer_sub
    end
  end
  
end