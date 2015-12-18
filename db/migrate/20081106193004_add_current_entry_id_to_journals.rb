class AddCurrentEntryIdToJournals < ActiveRecord::Migration
  def self.up
    add_column :journals, :current_entry_id, :integer, :after => :user_id, :null => true 
  end

  def self.down
    remove_column :journals, :current_entry_id
  end
end
