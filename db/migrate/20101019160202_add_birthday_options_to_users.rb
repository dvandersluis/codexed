class AddBirthdayOptionsToUsers < ActiveRecord::Migration
  def self.up
    add_column :users, :list_birthday, :boolean, :default => 1, :null => false, :after => :birthday
    add_column :users, :show_age, :boolean, :default => 1, :null => false, :after => :list_birthday
  end

  def self.down
    remove_column :users, :list_birthday
    remove_column :users, :show_age
  end
end
