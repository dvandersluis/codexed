require File.dirname(__FILE__)+'/test_helper'

describe Papyrus::Tokenizer do
  
  before :each do
    @tokenizer = Tokenizer.new(nil)
  end
  
  describe '.new' do
    it "should set @template to the given template" do
      Tokenizer.new(:template).ivg("@template").should == :template
    end
  end
  
  # TODO: Do we need to test flush_stack and all that?
  describe '#tokenize' do
    describe 'outside a sub' do
      it "should treat a string with no sub-specific symbols as text" do
        @tokenizer.stub_methods :content => StringScanner.new("This is a test sentence")
        @tokenizer.send :tokenize
        @tokenizer.ivg("@tokens").should == TokenList[ Token::Text.new("This is a test sentence") ]
      end
      it "should treat quotes outside a sub as just text" do
        @tokenizer.stub_methods :content => StringScanner.new("\"All's well that ends well\" was a phrase that has probably completely passed out of vogue.")
        @tokenizer.send :tokenize
        @tokenizer.ivg("@tokens").should == TokenList[ Token::Text.new("\"All's well that ends well\" was a phrase that has probably completely passed out of vogue.") ]
      end
      it "should not eat a backslash that is followed by anything other than left or right bracket, but treat it as text" do
        @tokenizer.stub_methods :content => StringScanner.new("Look at that! A back\\slash!")
        @tokenizer.send :tokenize
        @tokenizer.ivg("@tokens").should == TokenList[ Token::Text.new("Look at that! A back\\slash!") ]
      end
      it "should eat a backslash that is followed by a left or right bracket" do
        @tokenizer.stub_methods :content => StringScanner.new("\\[foo\\]")
        @tokenizer.send :tokenize
        @tokenizer.ivg("@tokens").should == TokenList[ Token::Text.new("[foo]") ]
      end
      it "should treat a forward slash not preceded by a left bracket as just text" do
        @tokenizer.stub_methods :content => StringScanner.new("Yes, Virginia, there / is such a thing as a forward slash.")
        @tokenizer.send :tokenize
        @tokenizer.ivg("@tokens").should == TokenList[ Token::Text.new("Yes, Virginia, there / is such a thing as a forward slash.") ]
      end
      it "should tokenize a left bracket individually" do
        @tokenizer.stub_methods :content => StringScanner.new("[")
        @tokenizer.send :tokenize
        @tokenizer.ivg("@tokens").should == TokenList[ Token::LeftBracket.new("[") ]
      end
    end
    describe 'inside a sub' do
      it "should tokenize a single quote individually" do
        @tokenizer.stub_methods :content => StringScanner.new("[']")
        @tokenizer.send :tokenize
        @tokenizer.ivg("@tokens").first.should == TokenList[ Token::LeftBracket.new, Token::SingleQuote.new, Token::RightBracket.new ]
      end
      it "should tokenize a double quote individually" do
        @tokenizer.stub_methods :content => StringScanner.new('["]')
        @tokenizer.send :tokenize
        @tokenizer.ivg("@tokens").first.should == TokenList[ Token::LeftBracket.new, Token::DoubleQuote.new, Token::RightBracket.new ]
      end
      it "should tokenize a slash individually if it directly follows the left bracket" do
        @tokenizer.stub_methods :content => StringScanner.new("[/]")
        @tokenizer.send :tokenize
        @tokenizer.ivg("@tokens").first.should == TokenList[ Token::LeftBracket.new, Token::Slash.new, Token::RightBracket.new ]
      end
      it "should tokenize a slash individually if there's whitespace between it and the left bracket" do
        @tokenizer.stub_methods :content => StringScanner.new("[ /]")
        @tokenizer.send :tokenize
        @tokenizer.ivg("@tokens").first.should == TokenList[ Token::LeftBracket.new, Token::Whitespace.new(" "), Token::Slash.new, Token::RightBracket.new ]
      end
      it "should not tokenize a slash individually if it appears anywhere else in the sub" do
        @tokenizer.stub_methods :content => StringScanner.new("[foo / bar]")
        @tokenizer.send :tokenize
        @tokenizer.ivg("@tokens").first.should_not include(Token::Slash.new("/"))
      end
      it "should tokenize whitespace individually" do
        @tokenizer.stub_methods :content => StringScanner.new("[ ]")
        @tokenizer.send :tokenize
        @tokenizer.ivg("@tokens").first.should == TokenList[ Token::LeftBracket.new("["), Token::Whitespace.new(" "), Token::RightBracket.new ]
      end
      it "should tokenize text individually" do
        @tokenizer.stub_methods :content => StringScanner.new("[foo]")
        @tokenizer.send :tokenize
        @tokenizer.ivg("@tokens").first.should == TokenList[ Token::LeftBracket.new, Token::Text.new("foo"), Token::RightBracket.new ]
      end
      it "should tokenize a right bracket individually" do
        @tokenizer.stub_methods :content => StringScanner.new("[]")
        @tokenizer.send :tokenize
        @tokenizer.ivg("@tokens").first.should == TokenList[ Token::LeftBracket.new, Token::RightBracket.new ]
      end
      it "should treat slashes as text if they precede a left or right bracket" do
        @tokenizer.stub_methods :content => StringScanner.new("[\\[x\\]]")
        @tokenizer.send :tokenize
        @tokenizer.ivg("@tokens").first.should == TokenList[ Token::LeftBracket.new, Token::Text.new("[x]"), Token::RightBracket.new ]
      end
      it "should correctly tokenize a nested sub" do
        @tokenizer.stub_methods :content => StringScanner.new("[foo [bar]]")
        @tokenizer.send :tokenize
        @tokenizer.ivg("@tokens").first.should == TokenList[
          Token::LeftBracket.new,
          Token::Text.new("foo"),
          Token::Whitespace.new(" "),
          TokenList[
            Token::LeftBracket.new,
            Token::Text.new("bar"),
            Token::RightBracket.new,
          ],
          Token::RightBracket.new
        ]
      end
    end
  end
  
end