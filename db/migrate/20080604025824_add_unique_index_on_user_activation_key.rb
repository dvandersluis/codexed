class AddUniqueIndexOnUserActivationKey < ActiveRecord::Migration
  def self.up
    add_index :users, :activation_key, :unique => true
  end

  def self.down
    remove_index :users, :activation_key
  end
end
