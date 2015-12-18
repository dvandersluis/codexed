class MakeUserFullNameOptional < ActiveRecord::Migration
  def self.up
    change_column :users, :first_name, :string, :limit => 50, :null => true
    change_column :users, :last_name, :string, :limit => 50, :null => true
  end

  def self.down
    change_column :users, :first_name, :string, :limit => 50, :null => false
    change_column :users, :last_name, :string, :limit => 50, :null => false
  end
end
