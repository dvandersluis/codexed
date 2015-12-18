class AddUserActivationAndDeletion < ActiveRecord::Migration
  def self.up
    add_column :users, :activation_key, :string, :after => :email, :null => false
    add_column :users, :activated_at, :datetime, :null => true
    add_column :users, :activation_email_sent_at, :datetime, :null => true
  end
  def self.down
    remove_column :users, :activation_key
    remove_column :users, :activated_at
    remove_column :users, :activation_email_sent_at
  end
end