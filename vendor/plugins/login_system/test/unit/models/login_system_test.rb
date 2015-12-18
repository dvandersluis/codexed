require File.dirname(__FILE__) + '/../unit_test_helper'

Expectations do
  
  # authenticate (when no such user)
  expect nil do
    User.stubs(:find_by_username).returns(nil)
    User.authenticate("bob", "secret")
  end
  # authenticate (when password doesn't match)
  expect nil do
    user = User.new
    user.stubs(:authenticates_against?).returns(false)
    User.stubs(:find_by_username).returns(user)
    User.authenticate("bob", "secret")
  end
  # authenticate (when user exists and password matches)
  expect User.new do
    user = User.new
    user.stubs(:authenticates_against?).returns(true)
    User.stubs(:find_by_username).returns(user)
    User.authenticate("bob", "secret")
  end
  
  # encrypt_password_using_salt
  expect "c398dfb6d7da0a9ee3000b82a0505862ef893447" do
    User.encrypt_password_using_salt('aaabbbccc', 'secretpassword')
  end
  
  # encrypt
  expect "5f5513f8822fdbe5145af33b64d8d970dcf95c6e" do
    User.send(:encrypt, "foobarbaz")
  end
  
  # authenticates_against? (when password matches)
  expect true do
    user = User.new(:crypted_password => "dklsfj093ulk")
    user.stubs(:encrypt_using_salt).returns("dklsfj093ulk")
    user.authenticates_against?("secret")
  end
  # authenticates_against? (when password doesn't match)
  expect false do
    user = User.new(:crypted_password => "lkdsf903lksaf")
    user.stubs(:encrypt_using_salt).returns("dklsfj093ulk")
    user.authenticates_against?("secret")
  end
  
  # set_mnemonic
  expect "dabe936219c65692064fb74dc23b6532753be1b1" do
    user = User.new
    user.stubs(:generated_mnemonic).returns("--1199167200--kdnfi493k--")
    user.set_mnemonic
    user.mnemonic
  end
  
  # set_mnemonic!
  expect User.new.to.receive(:set_mnemonic) do |user|
    # (save! already stubbed)
    user.set_mnemonic!
  end
  expect User.new.to.receive(:save!) do |user|
    user.stubs(:set_mnemonic)
    user.set_mnemonic!
  end
  
  # clear_mnemonic
  expect nil do
    user = User.new
    user.clear_mnemonic
    user.mnemonic
  end
  
  # clear_mnemonic!
  expect User.new.to.receive(:clear_mnemonic) do |user|
    # (save! already stubbed)
    user.clear_mnemonic!
  end
  expect User.new.to.receive(:save!) do |user|
    user.stubs(:clear_mnemonic)
    user.clear_mnemonic!
  end
  
  # reencrypt_password!
  expect User.new.to.receive(:encrypt_password) do |user|
    # (save! already stubbed)
    user.reencrypt_password!
  end
  expect User.new.to.receive(:save!) do |user|
    user.stubs(:encrypt_password)
    user.reencrypt_password!
  end
  
  # generated_mnemonic (without extra tokens)
  expect "--1199167200--kdnfi493k--" do
    Time.stubs(:now).returns(Time.local(2008))
    user = User.new(:crypted_password => "kdnfi493k")
    user.stubs(:login_participation_options).returns(:mnemonic_tokens => [])
    user.send :generated_mnemonic
  end
  
  # set_salt_and_encrypt_password
  expect User.new.to.receive(:set_salt) do |user|
    user.stubs(:encrypt_password)
    user.send :set_salt_and_encrypt_password
  end
  expect User.new.to.receive(:encrypt_password) do |user|
    user.stubs(:set_salt)
    user.send :set_salt_and_encrypt_password
  end
  
  # set_salt
  expect "0cdee41b83ebd93a39a4fb62f35141da3676655d" do
    Time.stubs(:now).returns(Time.local(2008))
    srand(100)
    user = User.new
    user.send :set_salt
    user.salt
  end
  
  # encrypt_password (if @password blank)
  expect nil do
    user = User.new
    user.send :encrypt_password
    user.crypted_password
  end
  # encrypt_password (if @password is not blank)
  expect "d9m2is9kdx" do
    user = User.new
    user.instance_variable_set("@password", "some password")
    user.stubs(:encrypt_using_salt).returns("d9m2is9kdx")
    user.send :encrypt_password
    user.crypted_password
  end
  
  # encrypt_using_salt
  expect User.to.receive(:encrypt_password_using_salt) do
    User.new.send :encrypt_using_salt, "something"
  end
  
end