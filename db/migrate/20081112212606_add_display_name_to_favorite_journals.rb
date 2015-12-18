class AddDisplayNameToFavoriteJournals < ActiveRecord::Migration
  def self.up
    add_column :favorite_journals, :display_name, :string, :limit => 30, :null => true, :after => :journal_id
  end

  def self.down
    remove_column :favorite_journals, :display_name
  end
end
