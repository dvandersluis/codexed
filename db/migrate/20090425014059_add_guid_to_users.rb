class AddGuidToUsers < ActiveRecord::Migration
  def self.up
    add_column :users, :guid, :string, :limit => 13, :after => :id
    add_index :users, :guid, :unique => true
    
    User.reset_column_information
    User.transaction do
      User.find_each(:batch_size => 100) do |user|
        user.generate_guid
        user.disabling_validations { user.save! }
        puts "Generated guid for user ##{user.id}."
      end
    end
  end

  def self.down
    remove_index :users, :column => :guid
    remove_column :users, :guid
  end
end
