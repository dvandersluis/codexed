class AddBirthdayToUsers < ActiveRecord::Migration
  def self.up
    add_column :users, :birthday, :date, :null => true, :after => :gender
  end

  def self.down
    remove_column :users, :birthday
  end
end
