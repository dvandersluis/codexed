require File.dirname(__FILE__) + '/../functional_spec_helper'

def default_user_data
  { :username => 'john', :password => 'secret' }
end
def new_user(attrs)
  User.new(attrs)
end
def default_user(attrs = {})
  User.new(default_user_data.merge(attrs))
end
def default_user_without(*attrs)
  User.new(default_user_data.except(*attrs))
end
def create_default_user(attrs = {})
  User.create!(default_user_data.merge(attrs))
end

describe "A user in the login system" do
  it "should be invalid without a username" do
    user = default_user_without(:username)
    user.should_not be_valid
    errors = user.errors.on(:username)
    errors.should_not be_blank
    errors.should include("can't be blank")
  end
  it "should be invalid without a password" do
    user = default_user_without(:password)
    user.should_not be_valid
    errors = user.errors.on(:password)
    errors.should_not be_blank
    errors.should include("can't be blank")
  end
  it "should be invalid if password is shorter than 4 letters" do
    user = default_user(:password => "xxx")
    user.should_not be_valid
    errors = user.errors.on(:password)
    errors.should_not be_blank
    errors.should include("is too short (minimum is 4 characters)")
  end
  it "should be invalid if password is longer than 20 letters" do
    user = default_user(:password => "xxxxxxxxxxxxxxxxxxxxx")
    user.should_not be_valid
    errors = user.errors.on(:password)
    errors.should_not be_blank
    errors.should include("is too long (maximum is 20 characters)")
  end
  it "should be invalid if confirming password and password_confirmation doesn't match password" do
    user = default_user(:password => "secret", :password_confirmation => "something else")
    user.should_not be_valid
    errors = user.errors.on(:password)
    errors.should_not be_blank
    errors.should include("doesn't match confirmation")
  end
  it "should be invalid if confirming presence of password_confirmation and it is blank" do
    user = default_user(:password_confirmation => "")
    user.validate_presence_of_password_confirmation!
    user.should_not be_valid
    errors = user.errors.on(:password_confirmation)
    errors.should_not be_blank
    errors.should include("can't be blank")
  end
  
  it "should set salt and encrypt_password before validation on create" do
    user = create_default_user
    user.salt.should_not be_blank
    user.crypted_password.should_not be_blank
  end
  
  it "should be authenticated when the given username and password are those of an existing user" do
    user = User.create!(:username => "john", :password => "secret")
    matching_user = User.authenticate("john", "secret")
    matching_user.should_not be_nil
    matching_user.id.should == user.id
  end
end
