class AddUserResetPasswordKey < ActiveRecord::Migration
  def self.up
    add_column :users, :reset_password_key, :string, :limit => 7, :null => true, :after => :activation_key
  end

  def self.down
    remove_column :users, :reset_password_key
  end
end
