require File.dirname(__FILE__) + '/test_helper'

class ExtraARAssertionsTest < ActiveRecord::TestCase
  def test_an_existing_and_found_model_are_technically_equal
    user = User.create!(:username => 'john', :password => 'secret', :first_name => "John")
    user2 = User.find(user.id)
    assert_equal user2, user
  end
  def test_an_existing_and_cloned_model_are_technically_not_equal
    user = User.create!(:username => 'john', :password => 'secret', :first_name => "John")
    user2 = user.clone
    assert_not_equal user2, user
  end
  def test_an_existing_and_found_model_are_technically_not_the_same_instance
    user = User.create!(:username => 'john', :password => 'secret', :first_name => "John")
    user2 = User.find(user.id)
    assert_not_same user2, user
  end
  def test_an_existing_and_cloned_model_are_technically_not_the_same_instance
    user = User.create!(:username => 'john', :password => 'secret', :first_name => "John")
    user2 = user.clone
    assert_not_same user2, user
  end
  
  def test_an_existing_and_found_model_should_be_functionally_equal
    user = User.create!(:username => 'john', :password => 'secret', :first_name => "John")
    user2 = User.find(user.id)
    assert_records_equal user2, user
  end
  def test_an_existing_and_cloned_model_should_be_functionally_equal
    user = User.create!(:username => 'john', :password => 'secret', :first_name => "John")
    user2 = user.clone
    assert_records_equal user2, user
  end
  def test_two_different_model_objects_should_not_be_equal
    user = User.create!(:username => 'john', :password => 'secret', :first_name => "John")
    type = EntryType.create!(:key => "A", :desc => "Uhm, something")
    assert_records_not_equal type, user
  end
  
  def test_an_existing_and_found_model_should_be_functionally_the_same
    user = User.create!(:username => 'john', :password => 'secret', :first_name => "John")
    user2 = User.find(user.id)
    assert_same_model user2, user
  end
  def test_an_existing_and_cloned_model_should_not_be_functionally_the_same
    user = User.create!(:username => 'john', :password => 'secret', :first_name => "John")
    user2 = user.clone
    assert_not_same_model user2, user
  end
  def test_two_different_model_objects_should_not_be_the_same
    user = User.create!(:username => 'john', :password => 'secret', :first_name => "John")
    type = EntryType.create!(:key => "A", :desc => "Uhm, something")
    assert_not_same_model type, user
  end
end
