class AddUsers < ActiveRecord::Migration
  def self.up
    create_table :users, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8' do |t|
      t.string :username, :limit => 30, :null => false
      t.string :crypted_password, :limit => 255, :null => false
      t.string :salt, :limit => 255, :null => false
      t.string :mnemonic, :limit => 255, :null => true
      t.string :first_name, :limit => 50, :null => false
      t.string :last_name, :limit => 50, :null => false
      t.string :display_name, :limit => 50, :null => true
      t.string :email, :limit => 50, :null => true
      #t.datetime :plus_begins_at, :null => true
      #t.datetime :plus_ends_at, :null => true
      t.datetime :created_at, :null => false
      t.datetime :updated_at, :null => false
      #t.column :user_status, 'char(1)', :null => false, :default => 'U'
      #t.column :status, 'char(1)', :null => false, :default => 'A'
    end
  end
  def self.down
    drop_table :users
  end
end
