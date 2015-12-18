require File.dirname(__FILE__)+'/test_helper'

describe "The tokenizer" do
  
  def tokenize(content)
    Tokenizer.new(Template.new(content)).tokenize
  end
  
  it "should correctly tokenize a closing sub with arguments and surrounding non-sub content" do
    tokens = tokenize("before the ] sub [/some args and stuff] after / the sub")
    tokens.should == TokenList[
      Token::Text.new("before the ] sub "),
      TokenList[
        Token::LeftBracket.new,
        Token::Slash.new,
        Token::Text.new("some"),
        Token::Whitespace.new(" "),
        Token::Text.new("args"),
        Token::Whitespace.new(" "),
        Token::Text.new("and"),
        Token::Whitespace.new(" "),
        Token::Text.new("stuff"),
        Token::RightBracket.new,
      ],
      Token::Text.new(" after / the sub")
    ]
  end
  
  it "should correctly tokenize nested subs" do
    tokens = tokenize("this [is a [nested sub [ok]]] ok")
    tokens.should == TokenList[
      Token::Text.new("this "),
      TokenList[
        Token::LeftBracket.new,
        Token::Text.new("is"),
        Token::Whitespace.new(" "),
        Token::Text.new("a"),
        Token::Whitespace.new(" "),
        TokenList[
          Token::LeftBracket.new,
          Token::Text.new("nested"),
          Token::Whitespace.new(" "),
          Token::Text.new("sub"),
          Token::Whitespace.new(" "),
          TokenList[
            Token::LeftBracket.new,
            Token::Text.new("ok"),
            Token::RightBracket.new
          ],
          Token::RightBracket.new
        ],
        Token::RightBracket.new
      ],
      Token::Text.new(" ok")
    ]
  end
  
  it "should correctly tokenize backslashed brackets" do
    tokens = tokenize("\\[foo\\]")
    tokens.should == TokenList[
      Token::Text.new("[foo]")
    ]
  end
  
  it "should correctly tokenize backslashed brackets with non-backslashed brackets" do
    tokens = tokenize("\\[foo\\] bar [baz]")
    tokens.should == TokenList[
      Token::Text.new("[foo] bar "),
      TokenList[
        Token::LeftBracket.new,
        Token::Text.new("baz"),
        Token::RightBracket.new
      ]
    ]
  end
  
end