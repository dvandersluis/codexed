class AddUserAdminFlag < ActiveRecord::Migration
  def self.up
    add_column :users, :admin, :boolean, :default => 0, :after => :activation_key
  end

  def self.down
    remove_column :users, :admin
  end
end
