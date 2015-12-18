require File.dirname(__FILE__)+'/test_helper'

describe Papyrus::Text do
  
  before :each do
    @text = Text.new('Some text and stuff')
  end
  
  describe '.new' do    
    it 'should store the given string' do
      @text.ivg('@text').should == 'Some text and stuff'
    end
    it 'should store the string inside the given Text instance' do
      @text = Text.new Token::Text.new("Some text and stuff")
      @text.ivg('@text').should == 'Some text and stuff'
    end
  end

  describe '#evaluate' do
    it 'should return the stored string' do
      @text.evaluate.should == 'Some text and stuff'
    end
    it 'should duplicate the stored string before returning it' do
      @text.evaluate.should_not equal(@text.text)
    end
  end
  
end