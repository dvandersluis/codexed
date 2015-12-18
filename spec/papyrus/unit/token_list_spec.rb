require File.dirname(__FILE__)+'/test_helper'

describe Papyrus::TokenList do
  
  before :each do
    @tokens = TokenList.new
  end
  
  describe '.[]' do
    it "should create a new TokenList using the given array" do
      TokenList['foo', 'bar', 'baz'].should == ['foo', 'bar', 'baz']
    end
  end
  
  describe '.new' do
    it "should initialize @pos" do
      @tokens.pos.should == -1
    end
  end
  
  describe '#add' do
    it "should add the given token to the last item if it is a TokenList itself and it is not ended by a right bracket" do
      tokens = TokenList[ TokenList.new ]
      tokens.add Token::Text.new("foo")
      tokens.should == TokenList[ TokenList[Token::Text.new("foo")] ]
    end
    it "should add the token straight to the TokenList if the last item is not a TokenList" do
      tokens = TokenList.new
      tokens.add Token::Text.new("foo")
      tokens.should == TokenList[ Token::Text.new("foo") ]
    end
    it "should add the token straight to the TokenList if the last item *is* a TokenList, but it is ended by a right bracket" do
      tokens = TokenList[ TokenList[ Token::RightBracket.new ] ]
      tokens.add Token::Text.new("foo")
      tokens.should == TokenList[ TokenList[Token::RightBracket.new], Token::Text.new("foo") ]
    end
  end
  
  describe '#advance' do
    it "should return the token at the next position" do
      @tokens.ivs "@brackets_open", 1
      @tokens.replace([
        Token::LeftBracket.new,
        Token::Text.new,
        Token::Slash.new
      ])
      @tokens.ivs "@pos", 0
      @tokens.advance.should be_a(Token::Text)
    end
  end
  
  describe '#curr' do
    it "should return the token at the current position" do
      tokens = TokenList[
        Token::Text.new,
        Token::LeftBracket.new,
        Token::Text.new
      ]
      tokens.ivs "@pos", 1
      tokens.curr.should be_a(Token::LeftBracket)
    end
  end
  
  describe '#next' do
    it "should return the token at the next position" do
      tokens = TokenList[
        Token::Text.new,
        Token::LeftBracket.new,
        Token::Text.new
      ]
      tokens.ivs "@pos", 1
      tokens.next
    end
  end
  
end